package sheettransform

import (
	"database/sql"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlSheetTransformStore(db *sql.DB, vada vada.VadaClient, log golog.Log) SheetTransformStore {

	getter := func(query string, colLen int, args ...interface{}) ([]*SheetTransform, error) {
		sts := make([]*SheetTransform, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			st := SheetTransform{}
			thumbnails := ""
			hash := ""
			if err := rows.Scan(&st.Id, &st.Sheet, &hash, &st.ClashChangeRegId, &st.DocumentVersion, &st.Project, &st.Name, &st.Manifest, &thumbnails, &st.Role); err != nil {
				return err
			}
			if tran, err := GetTransformFromHashJson(hash); err != nil {
				return err
			} else {
				st.Transform = *tran
			}
			st.Thumbnails = strings.Split(thumbnails, ",")
			sts = append(sts, &st)
			return nil
		}
		return sts, util.SqlQuery(db, rowsScan, query, args...)
	}

	get := func(forUser string, ids []string) ([]*SheetTransform, error) {
		return getter("CALL sheetGet(?, ?)", len(ids), forUser, strings.Join(ids, ","))
	}

	getForProjectSpaceVersion := func(forUser string, projectSpaceVersion string) ([]*SheetTransform, error) {
		return getter("CALL sheetGetForProjectSpaceVersion(?, ?)", forUser, projectSpaceVersion)
	}

	return newSheetTransformStore(get, getForProjectSpaceVersion, log)
}
