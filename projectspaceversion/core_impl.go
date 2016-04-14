package projectspaceversion

import (
	"errors"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"io"
	"net/http"
	"strings"
	"time"
)

func newProjectSpaceVersionStore(create create, get get, getForDocument getForDocument, getRole util.GetRole, bulkSetStatus bulkSetStatus, bulkSaveSheets bulkSaveSheets, statusCheckTimeout time.Duration, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) DocumentVersionStore {
	return &projectSpaceVersionStore{
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

type projectSpaceVersionStore struct {
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

func (psvs *projectSpaceVersionStore) Create(forUser string, projectSpace string, createComment string, thumbnailType string, thumbnail io.ReadCloser) (*DocumentVersion, error) {
	var projectId string

	if docVers, _, err := psvs.getForDocument(forUser, projectSpace, 0, 1, VersionAsc); err != nil || docVers == nil || len(docVers) == 0 {
		psvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileType: %q fileName: %q thumbnailType: %q error: %v", forUser, projectSpace, fileType, fileName, thumbnailType, err)
		return nil, err
	} else {
		projectId = docVers[0].Project
		if role, err := psvs.getRole(forUser, projectId); err != nil {
			psvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileType: %q fileName: %q thumbnailType: %q error: %v", forUser, projectSpace, fileType, fileName, thumbnailType, err)
			return nil, err
		} else if !(role == "owner" || role == "admin" || role == "organiser" || role == "contributor") {
			err := errors.New("Unauthorized Action: treeNode create document")
			psvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q fileType: %q fileName: %q thumbnailType: %q error: %v", forUser, projectSpace, fileType, fileName, thumbnailType, err)
			return nil, err
		}
	}

	if newDocVerId, status, urn, fileExtension, fileType, thumbnailType, err := util.DocumentUploadHelper(fileName, fileType, file, thumbnailType, thumbnail, psvs.ossBucketPrefix+projectId, psvs.vada, psvs.log); err != nil {
		return nil, err
	} else {
		if dv, err := psvs.create(forUser, projectSpace, newDocVerId, createComment, fileType, fileExtension, urn, status, thumbnailType); err != nil {
			psvs.log.Error("DocumentVersionStore.Create error: forUser: %q document: %q uploadComment: %q fileType: %q fileExtension: %q thumbnailType: %q error: %v", forUser, projectSpace, fileType, createComment, fileExtension, thumbnailType, err)
			return nil, err
		} else {
			psvs.log.Info("DocumentVersionStore.Create success: forUser: %q document: %q uploadComment: %q fileType: %q fileExtension: %q thumbnailType: %q", forUser, projectSpace, fileType, createComment, fileExtension, thumbnailType)
			return dv, nil
		}
	}
}

func (dvs *projectSpaceVersionStore) Get(forUser string, ids []string) ([]*DocumentVersion, error) {
	if docVers, err := dvs.get(forUser, ids); err != nil {
		dvs.log.Error("DocumentVersionStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		dvs.log.Info("DocumentVersionStore.Get success: forUser: %q ids: %v", forUser, ids)
		performStatusCheck(docVers, dvs.bulkSetStatus, dvs.bulkSaveSheets, dvs.statusCheckTimeout, dvs.vada, dvs.log)
		return docVers, nil
	}
}

func (psvs *projectSpaceVersionStore) GetForDocument(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error) {
	if docVers, totalResults, err := psvs.getForDocument(forUser, document, offset, limit, sortBy); err != nil {
		psvs.log.Error("DocumentVersionStore.GetForDocument error: forUser: %q document: %q offset: %d limit: %d sortBy: %q error: %v", forUser, document, offset, limit, sortBy, err)
		return docVers, totalResults, err
	} else {
		psvs.log.Info("DocumentVersionStore.GetForDocument success: forUser: %q document: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, document, offset, limit, sortBy, totalResults)
		performStatusCheck(docVers, psvs.bulkSetStatus, psvs.bulkSaveSheets, psvs.statusCheckTimeout, psvs.vada, psvs.log)
		return docVers, totalResults, nil
	}
}

func (psvs *projectSpaceVersionStore) GetThumbnail(forUser string, id string) (*http.Response, error) {
	if docVers, err := psvs.get(forUser, []string{id}); err != nil || docVers == nil || len(docVers) == 0 {
		psvs.log.Error("DocumentVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
		return nil, err
	} else {
		docVer := docVers[0]
		if strings.HasPrefix(docVer.ThumbnailType, "image/") {
			if res, err := psvs.vada.GetFile(docVer.Id+".tn.tn", psvs.ossBucketPrefix+docVer.Project); err != nil {
				psvs.log.Error("DocumentVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
				return res, err
			} else {
				psvs.log.Info("DocumentVersionStore.GetThumbnail success: forUser: %q id: %q", forUser, id)
				return res, err
			}
		} else {
			err = errors.New("DocumentVersion does not have a thumbnail")
			psvs.log.Error("DocumentVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
			return nil, err
		}
	}
}
