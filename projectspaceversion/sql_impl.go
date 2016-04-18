package projectspaceversion

import (
	"database/sql"
	"github.com/modelhub/core/sheettransform"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"strings"
)

func NewSqlProjectSpaceVersionStore(db *sql.DB, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) ProjectSpaceVersionStore {

	getter := func(query string, colLen int, args ...interface{}) ([]*ProjectSpaceVersion, error) {
		psvs := make([]*ProjectSpaceVersion, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			psv := ProjectSpaceVersion{}
			cameraJson := ""
			if err := rows.Scan(&psv.Id, &psv.ProjectSpace, &psv.Version, &psv.Project, &psv.Created, &psv.CreateComment, &psv.CreatedBy, &cameraJson, &psv.ThumbnailType, &psv.SheetTransformCount); err != nil {
				return err
			}
			psv.Camera, _ = json.FromString(cameraJson)
			psvs = append(psvs, &psv)
			return nil
		}
		return psvs, util.SqlQuery(db, rowsScan, query, args...)
	}

	offsetGetter := func(query string, args ...interface{}) ([]*ProjectSpaceVersion, int, error) {
		psvs := make([]*ProjectSpaceVersion, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			psv := ProjectSpaceVersion{}
			cameraJson := ""
			if err := rows.Scan(&totalResults, &psv.Id, &psv.ProjectSpace, &psv.Version, &psv.Project, &psv.Created, &psv.CreateComment, &psv.CreatedBy, &cameraJson, &psv.ThumbnailType, &psv.SheetTransformCount); err != nil {
				return err
			}
			psv.Camera, _ = json.FromString(cameraJson)
			psvs = append(psvs, &psv)
			return nil
		}
		return psvs, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	create := func(forUser string, projectSpace string, projectSpaceVersion string, createComment string, sheetTransforms []string, camera *json.Json, thumbnailType string) (*ProjectSpaceVersion, error) {
		cameraStr, _ := camera.ToString()
		if dvs, err := getter("CALL projectSpaceVersionCreate(?, ?, ?, ?, ?, ?)", 1, forUser, projectSpace, projectSpaceVersion, createComment, cameraStr, thumbnailType); len(dvs) == 1 {
			err = util.SqlExec(db, "CALL projectSpaceVersionSheetTransformCreate(?, ?)", projectSpaceVersion, strings.Join(sheetTransforms, ","))
			return dvs[0], err
		} else {
			return nil, err
		}
	}

	get := func(forUser string, ids []string) ([]*ProjectSpaceVersion, error) {
		return getter("CALL projectSpaceVersionGet(?, ?)", len(ids), forUser, strings.Join(ids, ","))
	}

	getForProjectSpace := func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceVersion, int, error) {
		return offsetGetter("CALL projectSpaceVersionGetForProjectSpace(?, ?, ?, ?, ?)", forUser, document, offset, limit, string(sortBy))
	}

	return newProjectSpaceVersionStore(create, get, getForProjectSpace, sheettransform.NewSqlSaveSheetTransformsFunc(db), util.GetRoleFunc(db), vada, ossBucketPrefix, log)
}
