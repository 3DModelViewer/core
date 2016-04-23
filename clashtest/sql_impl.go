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
			discard := ""
			if err := rows.Scan(&clashTestId, &discard, &discard); err != nil {
				return err
			}
			return nil
		}
		return clashTestId, util.SqlQuery(db, rowsScan, query, args...)
	}

	getForSheetTransforms := func(forUser string, leftSheetTransform string, rightSheetTransform string) (string, error) {
		return getter(db, "CALL clashTestGetForSheetTransforms(?, ?, ?)", forUser, leftSheetTransform, rightSheetTransform)
	}

	return newClashTestStore(getForSheetTransforms, caca, log)
}
