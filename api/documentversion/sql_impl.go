package documentversion

import (
	"database/sql"
	"github.com/modelhub/db/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"strings"
	"github.com/modelhub/db/api/sheet"
	"time"
)

func NewSqlDocumentVersionStore(db *sql.DB, statusCheckTimeout time.Duration, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) DocumentVersionStore {

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

	get := func(forUser string, ids []string) ([]*_documentVersion, error) {
		rows, err := db.Query("CALL documentVersionGet(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			dvs := make([]*_documentVersion, 0, len(ids))
			for rows.Next() {
				dv := _documentVersion{}
				if err = rows.Scan(&dv.Id, &dv.Document, &dv.Version, &dv.Project, &dv.Uploaded, &dv.UploadComment, &dv.UploadedBy, &dv.FileExtension, &dv.Urn, &dv.Status); err != nil {
					return dvs, err
				}
				dvs = append(dvs, &dv)
			}
			return dvs, err
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

	bulkSetStatus := func(docVers []*_documentVersion) error {
		if len(docVers) > 0 {
			query := ""
			args := make([]interface{}, 0, len(docVers)*2)
			for _, docVer := range docVers {
				query += "CALL documentVersionSetStatus(?, ?);"
				args = append(args, docVer.Id, docVer.Status)
			}
			_, err := db.Exec(query, args...)
			return err
		}
		return nil
	}

	bulkSaveSheets := func(sheets []*sheet.Sheet_) error {
		if len(sheets) > 0 {
			query := ""
			args := make([]interface{}, 0, len(sheets)*7)
			for _, sheet := range sheets {
				query += "CALL sheetCreate(?, ?, ?, ?, ?, ?, ?);"
				args = append(args, sheet.Id, sheet.Project, sheet.Name, sheet.BaseUrn, sheet.Manifest, strings.Join(sheet.Thumbnails, ","), sheet.Role)
			}
			_, err := db.Exec(query, args...)
			return err
		}
		return nil
	}

	return newDocumentVersionStore(create, get, getForDocument, util.GetRoleFunc(db), bulkSetStatus, bulkSaveSheets, statusCheckTimeout, vada, ossBucketPrefix, log)
}
