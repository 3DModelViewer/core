package sheettransform

import (
	"database/sql"
	"fmt"
	"github.com/modelhub/caca"
	"github.com/modelhub/core/util"
	"github.com/robsix/golog"
	"strings"
	"time"
)

func NewSqlSheetTransformStore(db *sql.DB, log golog.Log) SheetTransformStore {

	offsetGetter := func(query string, args ...interface{}) ([]*SheetTransform, int, error) {
		sts := make([]*SheetTransform, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			st := SheetTransform{}
			thumbnails := ""
			hash := ""
			if err := rows.Scan(&totalResults, &st.Id, &st.Sheet, &hash, &st.ClashChangeRegId, &st.DocumentVersion, &st.Project, &st.Name, &st.BaseUrn, &st.Manifest, &thumbnails, &st.Role); err != nil {
				return err
			}
			if tranObj, err := getTransformFromHashJson(hash); err != nil {
				return err
			} else {
				st.Transform = *tranObj.Transform
			}
			st.Thumbnails = strings.Split(thumbnails, ",")
			sts = append(sts, &st)
			return nil
		}
		return sts, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	get := func(forUser string, ids []string) ([]*SheetTransform, error) {
		return getter(db, "CALL sheetTransformGet(?, ?)", len(ids), forUser, strings.Join(ids, ","))
	}

	getForProjectSpaceVersion := func(forUser string, projectSpaceVersion string, offset int, limit int, sortBy sortBy) ([]*SheetTransform, int, error) {
		return offsetGetter("CALL sheetTransformGetForProjectSpaceVersion(?, ?, ?, ?, ?)", forUser, projectSpaceVersion, offset, limit, string(sortBy))
	}

	return newSheetTransformStore(get, getForProjectSpaceVersion, log)
}

func getter(db *sql.DB, query string, colLen int, args ...interface{}) ([]*SheetTransform, error) {
	sts := make([]*SheetTransform, 0, colLen)
	rowsScan := func(rows *sql.Rows) error {
		st := SheetTransform{}
		thumbnails := ""
		hash := ""
		if err := rows.Scan(&st.Id, &st.Sheet, &hash, &st.ClashChangeRegId, &st.DocumentVersion, &st.Project, &st.Name, &st.BaseUrn, &st.Manifest, &thumbnails, &st.Role); err != nil {
			return err
		}
		if tranObj, err := getTransformFromHashJson(hash); err != nil {
			return err
		} else {
			st.Transform = *tranObj.Transform
		}
		st.Thumbnails = strings.Split(thumbnails, ",")
		sts = append(sts, &st)
		return nil
	}
	return sts, util.SqlQuery(db, rowsScan, query, args...)
}

func _clashTestGetter(db *sql.DB, leftSheetTransform string, rightSheetTransform string) (string, error) {
	clashTestId := ""
	rowsScan := func(rows *sql.Rows) error {
		if err := rows.Scan(&clashTestId); err != nil {
			return err
		}
		return nil
	}
	return clashTestId, util.SqlQuery(db, rowsScan, "CALL _clashTest_getForSheetTransforms(?, ?)", leftSheetTransform, rightSheetTransform)
}

func NewSqlSaveSheetTransformsFunc(subTaskTimeOut time.Duration, db *sql.DB, caca caca.CacaClient, log golog.Log) func(forUser string, sheetTransforms []*SheetTransform) ([]*SheetTransform, error) {
	return func(forUser string, sheetTransforms []*SheetTransform) ([]*SheetTransform, error) {
		if len(sheetTransforms) > 0 {
			query := strings.Repeat("CALL sheetTransformCreate(%q, %q, '%v', %q); ", len(sheetTransforms))
			args := make([]interface{}, 0, len(sheetTransforms)*4)
			hashes := make([]string, 0, len(sheetTransforms))
			for _, st := range sheetTransforms {
				hash, err := getSheetTransformHashJson(st)
				hashes = append(hashes, hash)
				if err != nil {
					return sheetTransforms, err
				}
				args = append(args, forUser, st.Sheet, hash, util.EmptyUuid)
			}
			if err := util.SqlExec(db, fmt.Sprintf(query, args...)); err != nil {
				return sheetTransforms, err
			}
			sheetTransforms, err := getter(db, "CALL sheetTransformGetForHashJsons(?)", len(hashes), strings.Join(hashes, "#"))
			if caca != nil {
				if err := registerAnyUnregisteredSheetTransforms(sheetTransforms, subTaskTimeOut, db, caca, log); err != nil {
					return sheetTransforms, err
				} else {
					return sheetTransforms, registerAnyUnregisteredClashTests(forUser, sheetTransforms, subTaskTimeOut, db, caca, log)
				}
			}
			return sheetTransforms, err
		}
		return sheetTransforms, nil
	}
}

func registerAnyUnregisteredSheetTransforms(sheetTransforms []*SheetTransform, registrationTimeOut time.Duration, db *sql.DB, caca caca.CacaClient, log golog.Log) error {
	registrationsCount := 0
	var lastErr error
	errChan := make(chan error)
	for _, st := range sheetTransforms {
		if st.ClashChangeRegId == util.EmptyUuid {
			registrationsCount++
			go func(st *SheetTransform) {
				if regId, err := caca.RegisterSheet(st.BaseUrn + st.Manifest); err != nil {
					errChan <- err
					return
				} else {
					regId = strings.Replace(regId, "-", "", -1)
					if err := util.SqlExec(db, "CALL sheetTransformSetClashChangeRedId(?, ?)", st.Id, regId); err != nil {
						errChan <- err
						return
					} else {
						st.ClashChangeRegId = regId
						errChan <- nil
						return
					}
				}
			}(st)
		}
	}
	timeOutChan := time.After(registrationTimeOut)
	for registrationsCount > 0 {
		timedOut := false
		select {
		case err := <-errChan:
			registrationsCount--
			if err != nil {
				lastErr = err
			}
		case <-timeOutChan:
			log.Warning("ClashChangeSheetRegistrarion timed out after %v with %d open requests awaiting response", registrationTimeOut, registrationsCount)
			timedOut = true
		}
		if timedOut {
			break
		}
	}
	return lastErr
}

func registerAnyUnregisteredClashTests(forUser string, sheetTransforms []*SheetTransform, clashRegistrationTimeOut time.Duration, db *sql.DB, caca caca.CacaClient, log golog.Log) error {
	registrationsCount := 0
	var lastErr error
	errChan := make(chan error)
	for i := 0; i < len(sheetTransforms)-1; i++ {
		for j := i + 1; j < len(sheetTransforms); j++ {
			registrationsCount++
			go func(leftSheetTransform *SheetTransform, rightSheetTransform *SheetTransform) {
				if clashTestId, err := _clashTestGetter(db, leftSheetTransform.Id, rightSheetTransform.Id); err != nil {
					errChan <- err
					return
				} else if clashTestId == "" {
					if clashTestId, err := caca.RegisterClashTest(util.IdToUuidFormat(leftSheetTransform.ClashChangeRegId), util.IdToUuidFormat(rightSheetTransform.ClashChangeRegId)); err != nil {
						errChan <- err
						return
					} else {
						clashTestId = strings.Replace(clashTestId, "-", "", -1)
						errChan <- util.SqlExec(db, "CALL clashTestCreate(?, ?, ?, ?)", forUser, clashTestId, leftSheetTransform.Id, rightSheetTransform.Id)
					}
				} else {
					errChan <- nil
				}
			}(sheetTransforms[i], sheetTransforms[j])
		}
	}
	timeOutChan := time.After(clashRegistrationTimeOut)
	for registrationsCount > 0 {
		timedOut := false
		select {
		case err := <-errChan:
			registrationsCount--
			if err != nil {
				lastErr = err
			}
		case <-timeOutChan:
			log.Warning("ClashTestRegistrarion timed out after %v with %d open requests awaiting response", clashRegistrationTimeOut, registrationsCount)
			timedOut = true
		}
		if timedOut {
			break
		}
	}
	return lastErr
}
