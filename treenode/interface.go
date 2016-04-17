package treenode

import (
	"github.com/modelhub/core/sheettransform"
	"github.com/robsix/json"
	"io"
)

type createFolder func(forUser string, parent string, name string) (*TreeNode, error)
type createDocument func(forUser string, parent string, name string, documentVersion string, uploadComment string, fileType string, fileExtension string, urn string, status string, thumbnailType string) (*TreeNode, error)
type createProjectSpace func(forUser string, parent string, name string, projectSpaceVersion string, createComment string, sheetTransforms []string, camera *json.Json, thumbnailType string) (*TreeNode, error)
type setName func(forUser string, id string, newName string) error
type move func(forUser string, newParent string, ids []string) error
type get func(forUser string, ids []string) ([]*TreeNode, error)
type getChildren func(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
type getParents func(forUser string, id string) ([]*TreeNode, error)
type globalSearch func(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
type projectSearch func(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)

type TreeNodeStore interface {
	CreateFolder(forUser string, parent string, name string) (*TreeNode, error)
	CreateDocument(forUser string, parent string, name string, uploadComment string, fileType string, fileName string, file io.ReadCloser, thumbnailType string, thumbnail io.ReadCloser) (*TreeNode, error)
	CreateProjectSpace(forUser string, parent string, name string, createComment string, sheetTransforms []*sheettransform.SheetTransform, camera *json.Json, thumbnailType string, thumbnail io.ReadCloser) (*TreeNode, error)
	SetName(forUser string, id string, newName string) error
	Move(forUser string, newParent string, ids []string) error
	Get(forUser string, ids []string) ([]*TreeNode, error)
	GetChildren(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
	GetParents(forUser string, id string) ([]*TreeNode, error)
	GlobalSearch(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
	ProjectSearch(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
}
