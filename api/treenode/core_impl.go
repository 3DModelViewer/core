package treenode

import (
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"github.com/twinj/uuid"
	"mime/multipart"
)

func newTreeNodeStore(createFolder createFolder, createDocument createDocument, createViewerState createViewerState, setName setName, move move, getChildren getChildren, getParents getParents, globalSearch globalSearch, projectSearch projectSearch, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) TreeNodeStore {
	return &treeNodeStore{
		createFolder:      createFolder,
		createDocument:    createDocument,
		createViewerState: createViewerState,
		setName:           setName,
		move:              move,
		getChildren:       getChildren,
		getParents:        getParents,
		globalSearch:      globalSearch,
		projectSearch:     projectSearch,
		vada:              vada,
		ossBucketPrefix:   ossBucketPrefix,
		log:               log,
	}
}

type treeNodeStore struct {
	createFolder      createFolder
	createDocument    createDocument
	createViewerState createViewerState
	setName           setName
	move              move
	getChildren       getChildren
	getParents        getParents
	globalSearch      globalSearch
	projectSearch     projectSearch
	vada              vada.VadaClient
	ossBucketPrefix   string
	log               golog.Log
}

func (tns *treeNodeStore) CreateFolder(forUser string, parent string, name string) (*TreeNode, error) {
	if treeNode, err := tns.createFolder(forUser, parent, nodeType, name); err != nil {
		tns.log.Error("TreeNodeStore.CreateFolder error: forUser: %q parent: %q name: %q error: %v", forUser, parent, name, err)
		return treeNode, err
	} else {
		tns.log.Info("TreeNodeStore.CreateFolder success: forUser: %q parent: %q name: %q", forUser, parent, name)
		return treeNode, nil
	}
}

func (tns *treeNodeStore) CreateDocument(forUser string, parent string, name string, uploadComment string, fileExtension string, file multipart.File) (*TreeNode, error) {
	if treeNode, err := tns.createDocument(forUser, parent, nodeType, name, file); err != nil {
		tns.log.Error("TreeNodeStore.CreateDocument error: forUser: %q parent: %q name: %q uploadComment: %q fileExtension: %q error: %v", forUser, parent, name, uploadComment, fileExtension, err)
		return treeNode, err
	} else {
		tns.log.Info("TreeNodeStore.CreateDocument success: forUser: %q parent: %q name: %q uploadComment: %q fileExtension: %q treeNode: %v", forUser, parent, name, uploadComment, fileExtension, treeNode)
		return treeNode, nil
	}
}

func (tns *treeNodeStore) CreateViewerState(forUser string, parent string, name string, createComment string, definition *json.Json) (*TreeNode, error) {
	if treeNode, err := tns.createViewerState(forUser, parent, nodeType, name, definition); err != nil {
		tns.log.Error("TreeNodeStore.CreateViewerState error: forUser: %q parent: %q name: %q createComment: %q definition: %v error: %v", forUser, parent, name, createComment, definition.ToString(), err)
		return treeNode, err
	} else {
		tns.log.Info("TreeNodeStore.CreateViewerState success: forUser: %q parent: %q name: %q createComment: %q definition: %v treeNode: %v", forUser, parent, name, createComment, definition.ToString(), treeNode)
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
