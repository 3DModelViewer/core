package project

import (
	"database/sql"
	"github.com/robsix/golog"
	"github.com/modelhub/vada"
)

func NewSqlProjectStore(db *sql.DB, vada vada.VadaClient, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) ProjectStore {

	create := func(forUser string, name string, description string, imageFileExtension string) (*project, error) {
		return nil, nil
	}

	delete := func(forUser string, id string) error {
		return nil
	}

	setName := func(forUser string, id string, newName string) error {
		return nil
	}

	setDescription := func(forUser string, id string, newDescription string) error {
		return nil
	}

	setImageFileExtension := func(forUser string, id string, newImageFileExtension string) error {
		return nil
	}

	updateUserPermissions := func(sql string, forUser string, id string, users []string) error {
		return nil //strings.Join(users, ",")
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

	acceptInvitation := func(forUser string, project string) error {
		return nil
	}

	declineInvitation := func(forUser string, project string) error {
		return nil
	}

	get := func(forUser string, ids []string) ([]*project, error) {
		return nil, nil
	}

	getInUserContext := func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
		return nil, 0, nil
	}

	getInUserInviteContext := func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
		return nil, 0, nil
	}

	search := func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
		return nil, 0, nil
	}

	return newProjectStore(create, delete, setName, setDescription, setImageFileExtension, addOwners, addAdmins, addOrganisers, addContributors, addObservers, removeUsers, acceptInvitation, declineInvitation, get, getInUserContext, getInUserInviteContext, search, vada, ossBucketPrefix, ossBucketPolicy, log)
}
