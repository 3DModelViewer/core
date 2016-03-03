package sheet

import (
	"database/sql"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlSheetStore(db *sql.DB, vada vada.VadaClient, log golog.Log) SheetStore {

	getter := func(query string, colLen int, args ...interface{}) ([]*Sheet_, error) {
		ss := make([]*Sheet_, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			s := Sheet_{}
			thumbnails := ""
			if err := rows.Scan(&s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
				return err
			}
			s.Thumbnails = strings.Split(thumbnails, ",")
			ss = append(ss, &s)
			return nil
		}
		return ss, util.SqlQuery(db, rowsScan, query, args...)
	}

	offsetGetter := func(query string, args ...interface{}) ([]*Sheet_, int, error) {
		ss := make([]*Sheet_, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			s := Sheet_{}
			thumbnails := ""
			if err := rows.Scan(&totalResults, &s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
				return err
			}
			s.Thumbnails = strings.Split(thumbnails, ",")
			ss = append(ss, &s)
			return nil
		}
		return ss, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	setName := func(forUser string, id string, newName string) error {
		return util.SqlExec(db, "CALL sheetSetName(?, ?, ?)", forUser, id, newName)
	}

	get := func(forUser string, ids []string) ([]*Sheet_, error) {
		return getter("CALL sheetGet(?, ?)", len(ids), forUser, strings.Join(ids, ","))
	}

	getForDocumentVersion := func(forUser string, documentVersion string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		return offsetGetter("CALL sheetGetForDocumentVersion(?, ?, ?, ?, ?)", forUser, documentVersion, offset, limit, string(sortBy))
	}

	globalSearch := func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		return offsetGetter("CALL sheetGlobalSearch(?, ?, ?, ?, ?)", forUser, search, offset, limit, string(sortBy))
	}

	projectSearch := func(forUser string, project string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		return offsetGetter("CALL sheetProjectSearch(?, ?, ?, ?, ?, ?)", forUser, project, search, offset, limit, string(sortBy))
	}

	return newSheetStore(setName, get, getForDocumentVersion, globalSearch, projectSearch, vada, log)
}
