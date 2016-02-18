package treenode

import (
	"github.com/robsix/json"
	"mime/multipart"
)

type createFolder func(forUser string, parent string, name string) (*TreeNode, error)
type createDocument func(forUser string, parent string, name string, documentVersion string, uploadComment string, fileExtension string, urn string, status string) (*TreeNode, error)
type createViewerState func(forUser string, parent string, name string, comment string, definition *json.Json) (*TreeNode, error)
type setName func(forUser string, id string, newName string) error
type move func(forUser string, newParent string, ids []string) error
type get func(forUser string, ids []string) ([]*TreeNode, error)
type getChildren func(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
type getParents func(forUser string, id string) ([]*TreeNode, error)
type globalSearch func(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
type projectSearch func(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)

type TreeNodeStore interface {
	CreateFolder(forUser string, parent string, name string) (*TreeNode, error)
	CreateDocument(forUser string, parent string, name string, uploadComment string, fileName string, file multipart.File) (*TreeNode, error)
	CreateViewerState(forUser string, parent string, name string, createComment string, definition *json.Json) (*TreeNode, error)
	SetName(forUser string, id string, newName string) error
	Move(forUser string, newParent string, ids []string) error
	Get(forUser string, ids []string) ([]*TreeNode, error)
	GetChildren(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
	GetParents(forUser string, id string) ([]*TreeNode, error)
	GlobalSearch(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
	ProjectSearch(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error)
}
