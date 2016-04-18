package treenode

import (
	"errors"
	"github.com/modelhub/core/sheettransform"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"io"
)

func newTreeNodeStore(createFolder createFolder, createDocument createDocument, createProjectSpace createProjectSpace, saveSheetTransformsForProjectSpace sheettransform.SaveSheetTransformsForProjectSpace, setName setName, move move, get get, getChildren getChildren, getParents getParents, globalSearch globalSearch, projectSearch projectSearch, getRole util.GetRole, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) TreeNodeStore {
	return &treeNodeStore{
		createFolder:                       createFolder,
		createDocument:                     createDocument,
		createProjectSpace:                 createProjectSpace,
		saveSheetTransformsForProjectSpace: saveSheetTransformsForProjectSpace,
		setName:         setName,
		move:            move,
		get:             get,
		getChildren:     getChildren,
		getParents:      getParents,
		globalSearch:    globalSearch,
		projectSearch:   projectSearch,
		getRole:         getRole,
		vada:            vada,
		ossBucketPrefix: ossBucketPrefix,
		log:             log,
	}
}

type treeNodeStore struct {
	createFolder                       createFolder
	createDocument                     createDocument
	createProjectSpace                 createProjectSpace
	saveSheetTransformsForProjectSpace sheettransform.SaveSheetTransformsForProjectSpace
	setName                            setName
	move                               move
	get                                get
	getChildren                        getChildren
	getParents                         getParents
	globalSearch                       globalSearch
	projectSearch                      projectSearch
	getRole                            util.GetRole
	vada                               vada.VadaClient
	ossBucketPrefix                    string
	log                                golog.Log
}

func (tns *treeNodeStore) CreateFolder(forUser string, parent string, name string) (*TreeNode, error) {
	if treeNode, err := tns.createFolder(forUser, parent, name); err != nil {
		tns.log.Error("TreeNodeStore.CreateFolder error: forUser: %q parent: %q name: %q error: %v", forUser, parent, name, err)
		return treeNode, err
	} else {
		tns.log.Info("TreeNodeStore.CreateFolder success: forUser: %q parent: %q name: %q", forUser, parent, name)
		return treeNode, nil
	}
}

func (tns *treeNodeStore) CreateDocument(forUser string, parent string, name string, uploadComment string, fileType string, fileName string, file io.ReadCloser, thumbnailType string, thumbnail io.ReadCloser) (*TreeNode, error) {
	if file == nil {
		err := errors.New("file required")
		tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q fileType: %q thumbnailType: %q error: %v", forUser, parent, name, fileType, thumbnailType, err)
		return nil, err
	}
	defer file.Close()
	var projectId string

	if thumbnail != nil {
		defer thumbnail.Close()
	}

	if treeNodes, err := tns.get(forUser, []string{parent}); err != nil || treeNodes == nil {
		tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q fileType: %q thumbnailType: %q error: %v", forUser, parent, name, fileType, thumbnailType, err)
		return nil, err
	} else {
		projectId = treeNodes[0].Project
		if role, err := tns.getRole(forUser, projectId); err != nil {
			tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q fileType: %q thumbnailType: %q error: %v", forUser, parent, name, fileType, thumbnailType, err)
			return nil, err
		} else if !(role == "owner" || role == "admin" || role == "organiser" || role == "contributor") {
			err := errors.New("Unauthorized Action: treeNode create document")
			tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q fileType: %q thumbnailType: %q error: %v", forUser, parent, name, fileType, thumbnailType, err)
			return nil, err
		}
	}

	if newDocVerId, status, urn, fileExtension, fileType, thumbnailType, err := util.DocumentUploadHelper(fileName, fileType, file, thumbnailType, thumbnail, tns.ossBucketPrefix+projectId, tns.vada, tns.log); err != nil {
		return nil, err
	} else {
		if treeNode, err := tns.createDocument(forUser, parent, name, newDocVerId, uploadComment, fileType, fileExtension, urn, status, thumbnailType); err != nil {
			tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q uploadComment: %q fileType: %q fileExtension: %q thumbnailType: %q error: %v", forUser, parent, name, uploadComment, fileType, fileExtension, thumbnailType, err)
			return treeNode, err
		} else {
			tns.log.Info("TreeNodeStore.CreateDocument success: forUser: %q parent: %q name: %q uploadComment: %q fileType: %q fileExtension: %q thumbnailType: %q treeNode: %v", forUser, parent, name, uploadComment, fileType, fileExtension, thumbnailType, treeNode)
			return treeNode, nil
		}
	}
}

func (tns *treeNodeStore) CreateProjectSpace(forUser string, parent string, name string, createComment string, sheetTransforms []*sheettransform.SheetTransform, camera *json.Json, thumbnailType string, thumbnail io.ReadCloser) (*TreeNode, error) {
	var projectId string

	if thumbnail != nil {
		defer thumbnail.Close()
	}

	if treeNodes, err := tns.get(forUser, []string{parent}); err != nil || treeNodes == nil {
		tns.log.Error("TreeNodeStore.CreateProjectSpace error: forUser: %q parent: %q name: %q thumbnailType: %q error: %v", forUser, parent, name, thumbnailType, err)
		return nil, err
	} else {
		projectId = treeNodes[0].Project
		if role, err := tns.getRole(forUser, projectId); err != nil {
			tns.log.Error("TreeNodeStore.CreateProjectSpace error: forUser: %q parent: %q name: %q thumbnailType: %q error: %v", forUser, parent, name, thumbnailType, err)
			return nil, err
		} else if !(role == "owner" || role == "admin" || role == "organiser" || role == "contributor") {
			err := errors.New("Unauthorized Action: treeNode create projectSpace")
			tns.log.Error("TreeNodeStore.CreateProjectSpace error: forUser: %q parent: %q name: %q thumbnailType: %q error: %v", forUser, parent, name, thumbnailType, err)
			return nil, err
		}
	}

	sheetTransformIds := make([]string, 0, len(sheetTransforms))
	if completeSheetTransforms, err := tns.saveSheetTransformsForProjectSpace(forUser, sheetTransforms); err != nil {
		return nil, err
	} else {
		for _, st := range completeSheetTransforms {
			sheetTransformIds = append(sheetTransformIds, st.Id)
		}
	}

	newProjVerId := util.NewId()
	thumbnailType, _ = util.ThumbnailUploadHelper(newProjVerId, thumbnailType, thumbnail, tns.ossBucketPrefix+projectId, tns.vada)
	if treeNode, err := tns.createProjectSpace(forUser, parent, name, newProjVerId, createComment, sheetTransformIds, camera, thumbnailType); err != nil {
		tns.log.Error("TreeNodeStore.CreateProjectSpace error: forUser: %q parent: %q name: %q createComment: %q thumbnailType: %q error: %v", forUser, parent, name, createComment, thumbnailType, err)
		return treeNode, err
	} else {
		tns.log.Info("TreeNodeStore.CreateProjectSpace success: forUser: %q parent: %q name: %q createComment: %q thumbnailType: %q treeNode: %v", forUser, parent, name, createComment, thumbnailType, treeNode)
		return treeNode, nil
	}
}

func (tns *treeNodeStore) SetName(forUser string, id string, newName string) error {
	if err := tns.setName(forUser, id, newName); err != nil {
		tns.log.Error("TreeNodeStore.SetName error: forUser: %q id: %q newName: %q error: %q", forUser, id, newName, err)
		return err
	}
	tns.log.Info("TreeNodeStore.SetName success: forUser: %q id: %q newName: %q", forUser, id, newName)
	return nil
}

func (tns *treeNodeStore) Move(forUser string, newParent string, ids []string) error {
	if err := tns.move(forUser, newParent, ids); err != nil {
		tns.log.Error("TreeNodeStore.Move error: forUser: %q newParent: %q ids: %v error: %v", forUser, newParent, ids, err)
		return err
	}
	tns.log.Info("TreeNodeStore.Move success: forUser: %q newParent: %q ids: %v", forUser, newParent, ids)
	return nil
}

func (tns *treeNodeStore) Get(forUser string, ids []string) ([]*TreeNode, error) {
	if treeNodes, err := tns.get(forUser, ids); err != nil {
		tns.log.Error("TreeNodeStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		tns.log.Info("TreeNodeStore.Get success: forUser: %q ids: %v", forUser, ids)
		return treeNodes, nil
	}
}

func (tns *treeNodeStore) GetChildren(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
	if treeNodes, totalResults, err := tns.getChildren(forUser, id, nodeType, offset, limit, sortBy); err != nil {
		tns.log.Error("TreeNodeStore.GetChilren error: forUser: %q id: %q nodeType: %q offset: %d limit: %d sortBy: %q error: %v", forUser, id, nodeType, offset, limit, sortBy, err)
		return treeNodes, totalResults, err
	} else {
		tns.log.Info("TreeNodeStore.GetChilren success: forUser: %q id: %q nodeType: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, id, nodeType, offset, limit, sortBy, totalResults)
		return treeNodes, totalResults, nil
	}
}

func (tns *treeNodeStore) GetParents(forUser string, id string) ([]*TreeNode, error) {
	if treeNodes, err := tns.getParents(forUser, id); err != nil {
		tns.log.Error("TreeNodeStore.GetParents error: forUser: %q id: %q error: %v", forUser, id, err)
		return treeNodes, err
	} else {
		tns.log.Info("TreeNodeStore.GetParents success: forUser: %q id: %q treeNodes: %v", forUser, id, treeNodes)
		return treeNodes, nil
	}
}

func (tns *treeNodeStore) GlobalSearch(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
	if treeNodes, totalResults, err := tns.globalSearch(forUser, search, nodeType, offset, limit, sortBy); err != nil {
		tns.log.Error("TreeNodeStore.GlobalSearch error: forUser: %q search: %q nodeType: %q offset: %d limit: %d sortBy: %q error: %v", forUser, search, nodeType, offset, limit, sortBy, err)
		return treeNodes, totalResults, err
	} else {
		tns.log.Info("TreeNodeStore.GlobalSearch success: forUser: %q search: %q nodeType: %q offset: %d limit: %d sortBy: %q totalResults: %v", forUser, search, nodeType, offset, limit, sortBy, totalResults)
		return treeNodes, totalResults, nil
	}
}

func (tns *treeNodeStore) ProjectSearch(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
	if treeNodes, totalResults, err := tns.projectSearch(forUser, project, search, nodeType, offset, limit, sortBy); err != nil {
		tns.log.Error("TreeNodeStore.ProjectSearch error: forUser: %q project: %q search: %q nodeType: %q offset: %d limit: %d sortBy: %q error: %v", forUser, project, search, nodeType, offset, limit, sortBy, err)
		return treeNodes, totalResults, err
	} else {
		tns.log.Info("TreeNodeStore.ProjectSearch success: forUser: %q project: %q search: %q nodeType: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, project, search, nodeType, offset, limit, sortBy, totalResults)
		return treeNodes, totalResults, nil
	}
}
