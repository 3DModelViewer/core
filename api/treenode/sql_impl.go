package treenode

import (
	"database/sql"
	"git.autodesk.com/storm/documentversion"
	"git.autodesk.com/storm/permission"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"mime/multipart"
)

func NewSqlTreeNodeStore(db *sql.DB, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) (TreeNodeStore, error) {

	createFolder := func(forUser string, parent string, name string) (*TreeNode, error) {
		rows, err := db.Query("CALL treeNodeCreateFolder(?, ?, ?)", forUser, parent, name)

		if rows != nil {
			defer rows.Close()

		}
	}

	createDocument := func(forUser string, parent string, name string, uploadComment string, fileExtension string, file multipart.File) (*TreeNode, error) {

	}

	createViewerState := func(forUser string, parent string, name string, createComment string, definition *json.Json) (*TreeNode, error) {

	}

	setName := func(forUser string, id string, newName string) error {

	}

	move := func(forUser string, newParent string, ids []string) error {

	}

	getChildren := func(forUser string, id string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {

	}

	getParents := func(forUser string, id string) ([]*TreeNode, error) {

	}

	globalSearch := func(forUser string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {

	}

	projectSearch := func(forUser string, project string, search string, nodeType nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {

	}

	return newTreeNodeStore(createFolder, createDocument, createViewerState, setName, move, getChildren, getParents, globalSearch, projectSearch, log), nil
}
