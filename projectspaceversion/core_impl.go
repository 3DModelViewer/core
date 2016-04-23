package projectspaceversion

import (
	"errors"
	"github.com/modelhub/core/sheettransform"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"io"
	"net/http"
	"strings"
)

func newProjectSpaceVersionStore(create create, get get, getForProjectSpace getForProjectSpace, saveSheetTransformsForProjectSpace sheettransform.SaveSheetTransformsForProjectSpace, getRole util.GetRole, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) ProjectSpaceVersionStore {
	return &projectSpaceVersionStore{
		create:                             create,
		get:                                get,
		getForProjectSpace:                 getForProjectSpace,
		saveSheetTransformsForProjectSpace: saveSheetTransformsForProjectSpace,
		getRole:         getRole,
		vada:            vada,
		ossBucketPrefix: ossBucketPrefix,
		log:             log,
	}
}

type projectSpaceVersionStore struct {
	create                             create
	get                                get
	getForProjectSpace                 getForProjectSpace
	saveSheetTransformsForProjectSpace sheettransform.SaveSheetTransformsForProjectSpace
	getRole                            util.GetRole
	vada                               vada.VadaClient
	ossBucketPrefix                    string
	log                                golog.Log
}

func (psvs *projectSpaceVersionStore) Create(forUser string, projectSpace string, createComment string, sheetTransforms []*sheettransform.SheetTransform, camera *json.Json, thumbnailType string, thumbnail io.ReadCloser) (*ProjectSpaceVersion, error) {
	var projectId string

	if thumbnail != nil {
		defer thumbnail.Close()
	}

	if treeNodes, _, err := psvs.getForProjectSpace(forUser, projectSpace, 0, 1, VersionDesc); err != nil || treeNodes == nil {
		psvs.log.Error("ProjectSpaceVersionStore.Create error: forUser: %q projectSpace: %q thumbnailType: %q error: %v", forUser, projectSpace, thumbnailType, err)
		return nil, err
	} else {
		projectId = treeNodes[0].Project
		if role, err := psvs.getRole(forUser, projectId); err != nil {
			psvs.log.Error("ProjectSpaceVersionStore.Create error: forUser: %q projectSpace: %q thumbnailType: %q error: %v", forUser, projectSpace, thumbnailType, err)
			return nil, err
		} else if !(role == "owner" || role == "admin" || role == "organiser" || role == "contributor") {
			err := errors.New("Unauthorized Action: treeNode create projectSpace")
			psvs.log.Error("ProjectSpaceVersionStore.Create error: forUser: %q projectSpace: %q thumbnailType: %q error: %v", forUser, projectSpace, thumbnailType, err)
			return nil, err
		}
	}

	sheetTransformIds := make([]string, 0, len(sheetTransforms))
	if completeSheetTransforms, err := psvs.saveSheetTransformsForProjectSpace(forUser, sheetTransforms); err != nil {
		return nil, err
	} else {
		for _, st := range completeSheetTransforms {
			sheetTransformIds = append(sheetTransformIds, st.Id)
		}
	}

	newProjVerId := util.NewId()
	thumbnailType, _ = util.ThumbnailUploadHelper(newProjVerId, thumbnailType, thumbnail, psvs.ossBucketPrefix+projectId, psvs.vada)
	if treeNode, err := psvs.create(forUser, projectSpace, newProjVerId, createComment, sheetTransformIds, camera, thumbnailType); err != nil {
		psvs.log.Error("ProjectSpaceVersionStore.Create error: forUser: %q projectSpace: %q createComment: %q thumbnailType: %q error: %v", forUser, projectSpace, createComment, thumbnailType, err)
		return treeNode, err
	} else {
		psvs.log.Info("ProjectSpaceVersionStore.Create success: forUser: %q projectSpace: %q createComment: %q thumbnailType: %q treeNode: %v", forUser, projectSpace, createComment, thumbnailType, treeNode)
		return treeNode, nil
	}
}

func (psvs *projectSpaceVersionStore) Get(forUser string, ids []string) ([]*ProjectSpaceVersion, error) {
	if docVers, err := psvs.get(forUser, ids); err != nil {
		psvs.log.Error("ProjectSpaceVersionStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		psvs.log.Info("ProjectSpaceVersionStore.Get success: forUser: %q ids: %v", forUser, ids)
		return docVers, nil
	}
}

func (psvs *projectSpaceVersionStore) GetForProjectSpace(forUser string, projectSpace string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceVersion, int, error) {
	if docVers, totalResults, err := psvs.getForProjectSpace(forUser, projectSpace, offset, limit, sortBy); err != nil {
		psvs.log.Error("ProjectSpaceVersionStore.GetForProjectSpace error: forUser: %q projectSpace: %q offset: %d limit: %d sortBy: %q error: %v", forUser, projectSpace, offset, limit, sortBy, err)
		return docVers, totalResults, err
	} else {
		psvs.log.Info("ProjectSpaceVersionStore.GetForProjectSpace success: forUser: %q projectSpace: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, projectSpace, offset, limit, sortBy, totalResults)
		return docVers, totalResults, nil
	}
}

func (psvs *projectSpaceVersionStore) GetThumbnail(forUser string, id string) (*http.Response, error) {
	if projectSpaceVers, err := psvs.get(forUser, []string{id}); err != nil || projectSpaceVers == nil || len(projectSpaceVers) == 0 {
		psvs.log.Error("ProjectSpaceVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
		return nil, err
	} else {
		projectSpaceVer := projectSpaceVers[0]
		if strings.HasPrefix(projectSpaceVer.ThumbnailType, "image/") {
			if res, err := psvs.vada.GetFile(projectSpaceVer.Id+".tn.tn", psvs.ossBucketPrefix+projectSpaceVer.Project); err != nil {
				psvs.log.Error("ProjectSpaceVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
				return res, err
			} else {
				psvs.log.Info("ProjectSpaceVersionStore.GetThumbnail success: forUser: %q id: %q", forUser, id)
				return res, err
			}
		} else {
			err = errors.New("ProjectSpaceVersionStore does not have a thumbnail")
			psvs.log.Error("ProjectSpaceVersionStore.GetThumbnail error: forUser: %q id: %q error: %v", forUser, id, err)
			return nil, err
		}
	}
}
