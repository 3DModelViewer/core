package sheet

import (
	"database/sql"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlSheetStore(db *sql.DB, vada vada.VadaClient, log golog.Log) SheetStore {

	setName := func(forUser string, id string, newName string) error {
		_, err := db.Exec("CALL sheetSetName(?, ?, ?)", forUser, id, newName)
		return err
	}

	get := func(forUser string, ids []string) ([]*Sheet_, error) {
		rows, err := db.Query("CALL sheetGet(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			ss := make([]*Sheet_, 0, len(ids))
			for rows.Next() {
				s := Sheet_{}
				thumbnails := ""
				if err = rows.Scan(&s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
					return ss, err
				}
				s.Thumbnails = strings.Split(thumbnails, ",")
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
			ss := make([]*Sheet_, 0, 100)
			totalResults := 0
			for rows.Next() {
				s := Sheet_{}
				thumbnails := ""
				if err = rows.Scan(&totalResults, &s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
					return ss, totalResults, err
				}
				s.Thumbnails = strings.Split(thumbnails, ",")
				ss = append(ss, &s)
			}
			return ss, totalResults, err
		}

		return nil, 0, err
	}

	globalSearch := func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		rows, err := db.Query("CALL sheetGlobalSearch(?, ?, ?, ?, ?)", forUser, search, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			ss := make([]*Sheet_, 0, 100)
			totalResults := 0
			for rows.Next() {
				s := Sheet_{}
				thumbnails := ""
				if err = rows.Scan(&totalResults, &s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
					return ss, totalResults, err
				}
				s.Thumbnails = strings.Split(thumbnails, ",")
				ss = append(ss, &s)
			}
			return ss, totalResults, err
		}

		return nil, 0, err
	}

	projectSearch := func(forUser string, project string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error) {
		rows, err := db.Query("CALL sheetProjectSearch(?, ?, ?, ?, ?, ?)", forUser, project, search, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			ss := make([]*Sheet_, 0, 100)
			totalResults := 0
			for rows.Next() {
				s := Sheet_{}
				thumbnails := ""
				if err = rows.Scan(&totalResults, &s.Id, &s.DocumentVersion, &s.Project, &s.Name, &s.BaseUrn, &s.Manifest, &thumbnails, &s.Role); err != nil {
					return ss, totalResults, err
				}
				s.Thumbnails = strings.Split(thumbnails, ",")
				ss = append(ss, &s)
			}
			return ss, totalResults, err
		}

		return nil, 0, err
	}

	return newSheetStore(setName, get, getForDocumentVersion, globalSearch, projectSearch, vada, log)
}
