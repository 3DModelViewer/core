package sheet

import (
	"database/sql"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlSheetStore(db *sql.DB, vada vada.VadaClient, log golog.Log) SheetStore {

	get := func(forUser string, ids []string) ([]*Sheet_, error) {
		rows, err := db.Query("CALL documentVersionGet(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			ss := make([]*Sheet_, 0, len(ids))
			for rows.Next() {
				s := Sheet_{}
				if err = rows.Scan(); err != nil {
					return ss, err
				}
				ss = append(ss, &s)
			}
			return ss, err
		}

		return nil, err
	}

	getForDocumentVersion := func(forUser string, documentVersion string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		rows, err := db.Query("CALL sheetGetForDocumentVersion(?, ?, ?, ?, ?)", forUser, documentVersion, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			dvs := make([]*Sheet_, 0, 100)
			totalResults := 0
			for rows.Next() {
				dv := Sheet_{}
				if err = rows.Scan(); err != nil {
					return dvs, totalResults, err
				}
				dvs = append(dvs, &dv)
			}
			return dvs, totalResults, err
		}

		return nil, 0, err
	}

	return newSheetStore(setName, get, getForDocumentVersion, globalSearch, projectSearch, vada, log)
}
