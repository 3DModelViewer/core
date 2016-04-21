package sheettransform

import (
	"database/sql"
	"fmt"
	"github.com/modelhub/core/util"
	"github.com/robsix/golog"
	"strings"
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
			if err := rows.Scan(&totalResults, &st.Id, &st.Sheet, &hash, &st.ClashChangeRegId, &st.DocumentVersion, &st.Project, &st.Name, &st.Manifest, &thumbnails, &st.Role); err != nil {
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

func NewSqlSaveSheetTransformsFunc(db *sql.DB) func(forUser string, sheetTransforms []*SheetTransform) ([]*SheetTransform, error) {
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
				args = append(args, forUser, st.Sheet, hash, "00000000000000000000000000000000")
			}
			if err := util.SqlExec(db, fmt.Sprintf(query, args...)); err != nil {
				return sheetTransforms, err
			}
			sheetTransforms, err := getter(db, "CALL sheetTransformGetForHashJsons(?)", len(hashes), strings.Join(hashes, "#"))
			//TODO register any unregistered sheetTransforms with clashChangeService,
			//TODO create every sheetTransform pair to clash against
			//TODO check DB for which pairs have already been clashed
			//TODO clash any pairs which havent already been clashed
			return sheetTransforms, err
		}
		return sheetTransforms, nil
	}
}

func getter(db *sql.DB, query string, colLen int, args ...interface{}) ([]*SheetTransform, error) {
	sts := make([]*SheetTransform, 0, colLen)
	rowsScan := func(rows *sql.Rows) error {
		st := SheetTransform{}
		thumbnails := ""
		hash := ""
		if err := rows.Scan(&st.Id, &st.Sheet, &hash, &st.ClashChangeRegId, &st.DocumentVersion, &st.Project, &st.Name, &st.Manifest, &thumbnails, &st.Role); err != nil {
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
