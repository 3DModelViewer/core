package documentversion

import (
	"database/sql"
	"github.com/modelhub/core/api/sheet"
	"github.com/modelhub/core/util"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"strings"
	"time"
)

func NewSqlDocumentVersionStore(db *sql.DB, statusCheckTimeout time.Duration, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) DocumentVersionStore {

	getter := func(query string, colLen int, args ...interface{}) ([]*_documentVersion, error) {
		dvs := make([]*_documentVersion, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			dv := _documentVersion{}
			if err := rows.Scan(&dv.Id, &dv.Document, &dv.Version, &dv.Project, &dv.Uploaded, &dv.UploadComment, &dv.UploadedBy, &dv.FileExtension, &dv.Urn, &dv.Status); err != nil {
				return err
			}
			dvs = append(dvs, &dv)
			return nil
		}
		return dvs, util.SqlQuery(db, rowsScan, query, args...)
	}

	offsetGetter := func(query string, args ...interface{}) ([]*_documentVersion, int, error) {
		dvs := make([]*_documentVersion, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			dv := _documentVersion{}
			if err := rows.Scan(&totalResults, &dv.Id, &dv.Document, &dv.Version, &dv.Project, &dv.Uploaded, &dv.UploadComment, &dv.UploadedBy, &dv.FileExtension, &dv.Urn, &dv.Status); err != nil {
				return err
			}
			dvs = append(dvs, &dv)
			return nil
		}
		return dvs, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	create := func(forUser string, document string, documentVersion string, uploadComment, fileExtension string, urn string, status string) (*_documentVersion, error) {
		if dvs, err := getter("CALL documentVersionCreate(?, ?, ?, ?, ?, ?, ?)", 1, forUser, document, documentVersion, uploadComment, fileExtension, urn, status); len(dvs) == 1 {
			return dvs[0], err
		} else {
			return nil, err
		}
	}

	get := func(forUser string, ids []string) ([]*_documentVersion, error) {
		return getter("CALL documentVersionGet(?, ?)", len(ids), forUser, strings.Join(ids, ","))
	}

	getForDocument := func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*_documentVersion, int, error) {
		return offsetGetter("CALL documentVersionGetForDocument(?, ?, ?, ?, ?)", forUser, document, offset, limit, string(sortBy))
	}

	bulkSetStatus := func(docVers []*_documentVersion) error {
		if len(docVers) > 0 {
			query := strings.Repeat("CALL documentVersionSetStatus(?, ?);", len(docVers))
			args := make([]interface{}, 0, len(docVers)*2)
			for _, docVer := range docVers {
				args = append(args, docVer.Id, docVer.Status)
			}
			return util.SqlExec(db, query, args...)
		}
		return nil
	}

	bulkSaveSheets := func(sheets []*sheet.Sheet_) error {
		if len(sheets) > 0 {
			query := strings.Repeat("CALL sheetCreate(?, ?, ?, ?, ?, ?, ?);", len(sheets))
			args := make([]interface{}, 0, len(sheets)*7)
			for _, sheet := range sheets {
				args = append(args, sheet.DocumentVersion, sheet.Project, sheet.Name, sheet.BaseUrn, sheet.Manifest, strings.Join(sheet.Thumbnails, ","), sheet.Role)
			}
			return util.SqlExec(db, query, args...)
		}
		return nil
	}

	return newDocumentVersionStore(create, get, getForDocument, util.GetRoleFunc(db), bulkSetStatus, bulkSaveSheets, statusCheckTimeout, vada, ossBucketPrefix, log)
}
