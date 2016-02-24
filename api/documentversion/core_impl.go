package documentversion

import (
	"errors"
	"github.com/modelhub/core/util"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"io"
	"net/http"
	"path/filepath"
	"time"
)

func newDocumentVersionStore(create create, get get, getForDocument getForDocument, getRole util.GetRole, bulkSetStatus bulkSetStatus, bulkSaveSheets bulkSaveSheets, statusCheckTimeout time.Duration, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) DocumentVersionStore {
	return &documentVersionStore{
		create:             create,
		get:                get,
		getForDocument:     getForDocument,
		getRole:            getRole,
		bulkSetStatus:      bulkSetStatus,
		bulkSaveSheets:     bulkSaveSheets,
		statusCheckTimeout: statusCheckTimeout,
		ossBucketPrefix:    ossBucketPrefix,
		vada:               vada,
		log:                log,
	}
}

type documentVersionStore struct {
	create             create
	get                get
	getForDocument     getForDocument
	getRole            util.GetRole
	bulkSetStatus      bulkSetStatus
	bulkSaveSheets     bulkSaveSheets
	statusCheckTimeout time.Duration
	vada               vada.VadaClient
	ossBucketPrefix    string
	log                golog.Log
}

func (dvs *documentVersionStore) Create(forUser string, document string, uploadComment string, fileName string, file io.ReadCloser) (*DocumentVersion, error) {
	if file == nil {
		err := errors.New("file required")
		dvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileName: %q error: %v", forUser, document, fileName, err)
		return nil, err
	}
	defer file.Close()
	var projectId string

	if docVers, _, err := dvs.getForDocument(forUser, document, 0, 1, VersionAsc); err != nil || docVers == nil || len(docVers) == 0 {
		dvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileName: %q error: %v", forUser, document, fileName, err)
		return nil, err
	} else {
		projectId = docVers[0].Project
		if role, err := dvs.getRole(forUser, projectId); err != nil {
			dvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileName: %q error: %v", forUser, document, fileName, err)
			return nil, err
		} else if role != "owner" || role != "admin" || role != "organiser" || role != "contributor" {
			err := errors.New("Unauthorized Action: treeNode create document")
			dvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileName: %q error: %v", forUser, document, fileName, err)
			return nil, err
		}
	}

	fileExtension := filepath.Ext(fileName)
	if len(fileExtension) >= 1 {
		fileExtension = fileExtension[1:] //cut of the .
	}

	if newDocVerId, status, urn, err := util.DocumentUploadHelper(fileName, file, dvs.ossBucketPrefix+projectId, dvs.vada, dvs.log); err != nil {
		return nil, err
	} else {
		if dv, err := dvs.create(forUser, document, newDocVerId, uploadComment, fileExtension, urn, status); err != nil {
			dvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q uploadComment: %q fileName: %q error: %v", forUser, document, uploadComment, fileName, err)
			return nil, err
		} else {
			dvs.log.Info("DocumentVersionStore.Create success: forUser: %q document: %q uploadComment: %q fileName: %q", forUser, document, uploadComment, fileName)
			return convertToPublicFormat([]*_documentVersion{dv})[0], nil
		}
	}
}

func (dvs *documentVersionStore) Get(forUser string, ids []string) ([]*DocumentVersion, error) {
	if docVers, err := dvs.get(forUser, ids); err != nil {
		dvs.log.Error("DocumentVersionStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		dvs.log.Info("DocumentVersionStore.Get success: forUser: %q ids: %v", forUser, ids)
		performStatusCheck(docVers, dvs.bulkSetStatus, dvs.bulkSaveSheets, dvs.statusCheckTimeout, dvs.vada, dvs.log)
		return convertToPublicFormat(docVers), nil
	}
}

func (dvs *documentVersionStore) GetForDocument(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error) {
	if docVers, totalResults, err := dvs.getForDocument(forUser, document, offset, limit, sortBy); err != nil {
		dvs.log.Error("DocumentVersionStore.GetForDocument error: forUser: %q document: %q offset: %d limit: %d sortBy: %q error: %v", forUser, document, offset, limit, sortBy, err)
		return convertToPublicFormat(docVers), totalResults, err
	} else {
		dvs.log.Info("DocumentVersionStore.GetForDocument success: forUser: %q document: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, document, offset, limit, sortBy, totalResults)
		performStatusCheck(docVers, dvs.bulkSetStatus, dvs.bulkSaveSheets, dvs.statusCheckTimeout, dvs.vada, dvs.log)
		return convertToPublicFormat(docVers), totalResults, nil
	}
}

func (dvs *documentVersionStore) GetSeedFile(forUser string, id string) (*http.Response, error) {
	if docVers, err := dvs.get(forUser, []string{id}); err != nil || docVers == nil || len(docVers) == 0 {
		dvs.log.Error("DocumentVersionStore.GetSeedFile error: forUser: %q id: %q error: %v", forUser, id, err)
		return nil, err
	} else {
		if role, err := dvs.getRole(forUser, docVers[0].Project); err != nil {
			dvs.log.Error("DocumentVersionStore.GetSeedFile error: forUser: %q id: %q error: %v", forUser, id, err)
			return nil, err
		} else if role != "owner" || role != "admin" || role != "organiser" || role != "contributor" {
			err := errors.New("Unauthorized Action: treeNode create document")
			dvs.log.Error("DocumentVersionStore.GetSeedFile error: forUser: %q id: %q error: %v", forUser, id, err)
			return nil, err
		}
		docVer := docVers[0]
		return dvs.vada.GetFile(docVer.Id+"."+docVer.FileExtension, dvs.ossBucketPrefix+docVer.Project)
	}
}
