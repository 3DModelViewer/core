package sheet

import (
	"database/sql"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlSheetStore(db *sql.DB, vada vada.VadaClient, log golog.Log) SheetStore {

	create := func(forUser string, document string, documentVersion string, uploadComment, fileExtension string, urn string, status string) (*DocumentVersion, error) {
		rows, err := db.Query("CALL documentVersionCreate(?, ?, ?, ?, ?, ?, ?)", forUser, document, documentVersion, uploadComment, fileExtension, urn, status)

		dv := DocumentVersion{}
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				urn := ""
				err = rows.Scan(&dv.Id, &dv.Document, &dv.Version, &dv.Project, &dv.Uploaded, &dv.UploadComment, &dv.UploadedBy, &dv.FileExtension, &urn, &dv.Status)
			}
		}

		return &dv, err
	}

	get := func(forUser string, ids []string) ([]*Sheet_, error) {
		rows, err := db.Query("CALL documentVersionGet(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			ss := make([]*Sheet_, 0, len(ids))
			for rows.Next() {
				s := Sheet_{}
				if err = rows.Scan(&s.Id, &s.Document, &s.Version, &s.Project, &s.Uploaded, &s.UploadComment, &s.UploadedBy, &s.FileExtension, &s.Urn, &s.Status); err != nil {
					return ss, err
				}
				ss = append(ss, &s)
			}
			return ss, err
		}

		return nil, err
	}

	getForDocument := func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*_documentVersion, int, error) {
		rows, err := db.Query("CALL documentVersionGetForDocument(?, ?, ?, ?, ?)", forUser, document, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			dvs := make([]*_documentVersion, 0, 100)
			totalResults := 0
			for rows.Next() {
				dv := _documentVersion{}
				if err = rows.Scan(&totalResults, &dv.Id, &dv.Document, &dv.Version, &dv.Project, &dv.Uploaded, &dv.UploadComment, &dv.UploadedBy, &dv.FileExtension, &dv.Urn, &dv.Status); err != nil {
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
