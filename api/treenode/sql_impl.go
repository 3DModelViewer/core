package treenode

import (
	"database/sql"
	"github.com/modelhub/core/util"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"strings"
)

func NewSqlTreeNodeStore(db *sql.DB, vada vada.VadaClient, ossBucketPrefix string, log golog.Log) TreeNodeStore {

	createFolder := func(forUser string, parent string, name string) (*TreeNode, error) {
		rows, err := db.Query("CALL treeNodeCreateFolder(?, ?, ?)", forUser, parent, name)

		tn := TreeNode{}
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				scanNodeType := ""
				err = rows.Scan(&tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType)
				tn.NodeType = nodeType(scanNodeType)
			}
		}

		return &tn, err
	}

	createDocument := func(forUser string, parent string, name string, documentVersion string, uploadComment string, fileExtension string, urn string, status string) (*TreeNode, error) {
		rows, err := db.Query("CALL treeNodeCreateDocument(?, ?, ?, ?, ?, ?, ?, ?)", forUser, parent, name, documentVersion, uploadComment, fileExtension, urn, status)

		tn := TreeNode{}
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				scanNodeType := ""
				err = rows.Scan(&tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType)
				tn.NodeType = nodeType(scanNodeType)
			}
		}

		return &tn, err
	}

	createViewerState := func(forUser string, parent string, name string, createComment string, definition *json.Json) (*TreeNode, error) {
		//todo
		return nil, nil
	}

	setName := func(forUser string, id string, newName string) error {
		_, err := db.Exec("CALL treeNodeSetName(?, ?, ?)", forUser, id, newName)
		return err
	}

	move := func(forUser string, newParent string, ids []string) error {
		_, err := db.Exec("CALL treeNodeMove(?, ?, ?)", forUser, newParent, strings.Join(ids, ","))
		return err
	}

	get := func(forUser string, ids []string) ([]*TreeNode, error) {
		rows, err := db.Query("CALL treeNodeGetChildren(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			tns := make([]*TreeNode, 0, len(ids))
			for rows.Next() {
				tn := TreeNode{}
				scanNodeType := ""
				if err = rows.Scan(&tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType); err != nil {
					return tns, err
				}
				tn.NodeType = nodeType(scanNodeType)
				tns = append(tns, &tn)
			}
			return tns, err
		}

		return nil, err
	}

	getChildren := func(forUser string, id string, nt nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
		rows, err := db.Query("CALL treeNodeGetChildren(?, ?, ?, ?, ?, ?)", forUser, id, string(nt), offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			tns := make([]*TreeNode, 0, 100)
			totalResults := 0
			for rows.Next() {
				tn := TreeNode{}
				scanNodeType := ""
				if err = rows.Scan(&totalResults, &tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType); err != nil {
					return tns, totalResults, err
				}
				tn.NodeType = nodeType(scanNodeType)
				tns = append(tns, &tn)
			}
			return tns, totalResults, err
		}

		return nil, 0, err
	}

	getParents := func(forUser string, id string) ([]*TreeNode, error) {
		rows, err := db.Query("CALL treeNodeGetParents(?, ?)", forUser, id)

		if rows != nil {
			defer rows.Close()
			tns := make([]*TreeNode, 0, 100)
			for rows.Next() {
				tn := TreeNode{}
				scanNodeType := ""
				if err = rows.Scan(&tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType); err != nil {
					return tns, err
				}
				tn.NodeType = nodeType(scanNodeType)
				tns = append(tns, &tn)
			}
			return tns, err
		}

		return nil, err
	}

	globalSearch := func(forUser string, search string, nt nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
		rows, err := db.Query("CALL treeNodeGlobalSearch(?, ?, ?, ?, ?, ?)", forUser, search, string(nt), offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			tns := make([]*TreeNode, 0, 100)
			totalResults := 0
			for rows.Next() {
				tn := TreeNode{}
				scanNodeType := ""
				if err = rows.Scan(&totalResults, &tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType); err != nil {
					return tns, totalResults, err
				}
				tn.NodeType = nodeType(scanNodeType)
				tns = append(tns, &tn)
			}
			return tns, totalResults, err
		}

		return nil, 0, err
	}

	projectSearch := func(forUser string, project string, search string, nt nodeType, offset int, limit int, sortBy sortBy) ([]*TreeNode, int, error) {
		rows, err := db.Query("CALL treeNodeProjectSearch(?, ?, ?, ?, ?, ?, ?)", forUser, project, search, string(nt), offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			tns := make([]*TreeNode, 0, 100)
			totalResults := 0
			for rows.Next() {
				tn := TreeNode{}
				scanNodeType := ""
				if err = rows.Scan(&totalResults, &tn.Id, &tn.Parent, &tn.Project, &tn.Name, &scanNodeType); err != nil {
					return tns, totalResults, err
				}
				tn.NodeType = nodeType(scanNodeType)
				tns = append(tns, &tn)
			}
			return tns, totalResults, err
		}

		return nil, 0, err
	}

	return newTreeNodeStore(createFolder, createDocument, createViewerState, setName, move, get, getChildren, getParents, globalSearch, projectSearch, util.GetRoleFunc(db), vada, ossBucketPrefix, log)
}
