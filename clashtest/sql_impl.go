package clashtest

import (
	"database/sql"
	"github.com/modelhub/caca"
	"github.com/modelhub/core/util"
	"github.com/robsix/golog"
)

func NewSqlClashTestStore(db *sql.DB, caca caca.CacaClient, log golog.Log) ClashTestStore {

	getter := func(query string, args ...interface{}) (string, error) {
		clashTestId := ""
		rowsScan := func(rows *sql.Rows) error {
			if err := rows.Scan(&clashTestId); err != nil {
				return err
			}
			return nil
		}
		return clashTestId, util.SqlQuery(db, rowsScan, query, args...)
	}

	getForSheetTransforms := func(forUser string, leftSheetTransform string, rightSheetTransform string) (string, bool, error) {
		clashTestId, err := getter("CALL clashTestGetForSheetTransforms(?, ?, ?)", forUser, leftSheetTransform, rightSheetTransform)
		var exists bool
		if clashTestId == "" {
			exists = false
		} else {
			exists = true
		}
		return clashTestId, exists, err
	}

	return newClashTestStore(getForSheetTransforms, caca, log)
}
