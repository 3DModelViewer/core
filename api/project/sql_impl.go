package project

import (
	"database/sql"
	"github.com/robsix/golog"
	"github.com/modelhub/vada"
	"strings"
)

func NewSqlProjectStore(db *sql.DB, vada vada.VadaClient, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) ProjectStore {

	create := func(forUser string, name string, description string, imageFileExtension string) (*Project, error) {
		rows, err := db.Query("CALL projectCreate(?, ?, ?, ?)", forUser, name, description, imageFileExtension)

		if rows != nil {
			defer rows.Close()
			p := Project{}
			for rows.Next() {
				if err := rows.Scan(&p.Id, &p.Name, &p.Description, &p.Created, &p.ImageFileExtension); err != nil {
					return &p, err
				}
			}
			return &p, err
		}

		return nil, err
	}

	delete := func(forUser string, id string) error {
		_, err := db.Exec("CALL projectDelete(?, ?)", forUser, id)
		return err
	}

	setName := func(forUser string, id string, newName string) error {
		_, err := db.Exec("CALL projectSetName(?, ?, ?)", forUser, id, newName)
		return err
	}

	setDescription := func(forUser string, id string, newDescription string) error {
		_, err := db.Exec("CALL projectSetDescription(?, ?, ?)", forUser, id, newDescription)
		return err
	}

	setImageFileExtension := func(forUser string, id string, newImageFileExtension string) error {
		_, err := db.Exec("CALL projectSetImageFileExtension(?, ?, ?)", forUser, id, newImageFileExtension)
		return err
	}

	updateUserPermissions := func(sql string, forUser string, id string, users []string) error {
		_, err := db.Exec(sql, forUser, id, strings.Join(users, ","))
		return err
	}

	addOwners := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectAddOwners(?, ?, ?)", forUser, id, users)
	}

	addAdmins := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectAddAdmins(?, ?, ?)", forUser, id, users)
	}

	addOrganisers := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectAddOrganisers(?, ?, ?)", forUser, id, users)
	}

	addContributors := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectAddContributors(?, ?, ?)", forUser, id, users)
	}

	addObservers := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectAddObservers(?, ?, ?)", forUser, id, users)
	}

	removeUsers := func(forUser string, id string, users []string) error {
		return updateUserPermissions("CALL projectRemoveUsers(?, ?, ?)", forUser, id, users)
	}

	acceptInvitation := func(forUser string, id string) error {
		_, err := db.Exec("CALL projectAcceptInvitation(?, ?)", forUser, id)
		return err
	}

	declineInvitation := func(forUser string, id string) error {
		_, err := db.Exec("CALL projectDeclineInvitation(?, ?)", forUser, id)
		return err
	}

	getRole := func(forUser string, id string) (string, error) {
		rows, err := db.Query("CALL projectGetRole(?, ?)", forUser, id)

		if rows != nil {
			defer rows.Close()
			role := ""
			for rows.Next() {
				if err := rows.Scan(&role); err != nil {
					return role, err
				}
			}
			return role, err
		}

		return "", err
	}

	get := func(forUser string, ids []string) ([]*Project, error) {
		rows, err := db.Query("CALL projectGet(?, ?)", forUser, strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			ps := make([]*Project, 0, 100)
			for rows.Next() {
				p := Project{}
				if err := rows.Scan(&p.Id, &p.Name, &p.Description, &p.Created, &p.ImageFileExtension); err != nil {
					return ps, err
				}
				ps = append(ps, &p)
			}
			return ps, err
		}

		return nil, err
	}

	_getInUserContext := func(sql string, forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error) {
		rows, err := db.Query(sql, forUser, user, role, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			totalResults := 0
			ps := make([]*ProjectInUserContext, 0, 100)
			for rows.Next() {
				p := ProjectInUserContext{}
				if err := rows.Scan(&totalResults, &p.Id, &p.Name, &p.Description, &p.Created, &p.ImageFileExtension); err != nil {
					return ps, totalResults, err
				}
				ps = append(ps, &p)
			}
			return ps, totalResults, err
		}

		return nil, 0, err
	}

	getInUserContext := func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error) {
		return _getInUserContext("CALL projectGetInUserContext(?, ?, ?, ?, ?, ?)", forUser, user, role, offset, limit, sortBy)
	}

	getInUserInviteContext := func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error) {
		return _getInUserContext("CALL projectGetInUserInviteContext(?, ?, ?, ?, ?, ?)", forUser, user, role, offset, limit, sortBy)
	}

	search := func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error) {
		return nil, 0, nil
	}

	return newProjectStore(create, delete, setName, setDescription, setImageFileExtension, addOwners, addAdmins, addOrganisers, addContributors, addObservers, removeUsers, acceptInvitation, declineInvitation, getRole, get, getInUserContext, getInUserInviteContext, search, vada, ossBucketPrefix, ossBucketPolicy, log)
}
