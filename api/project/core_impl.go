package project

import (
	"github.com/robsix/golog"
	"github.com/modelhub/vada"
	"mime/multipart"
)

func newProjectStore(create create, setName setName, setDescription setDescription, setImage setImageFileExtension, addOwners updateUserPermissions, addAdmins updateUserPermissions, addOrganisers updateUserPermissions, addContributors updateUserPermissions, addObservers updateUserPermissions, removeUsers updateUserPermissions, get get, getInUserContext getInUserContext, getInUserInviteContext getInUserContext, search search, vada vada.VadaClient, log golog.Log) ProjectStore {
	return &projectStore{
		create:             create,
		setName:             setName,
		setDescription:  setDescription,
		setImage:     setImage,
		addOwners:          addOwners,
		addAdmins:         addAdmins,
		addOrganisers:         addOrganisers,
		addContributors:         addContributors,
		addObservers:         addObservers,
		removeUsers:        removeUsers,
		get:                get,
		getInUserContext: getInUserContext,
		getInUserInviteContext: getInUserInviteContext,
		search:             search,
		vada:               vada,
		log:                log,
	}
}

type projectStore struct {
	create             create
	setName setName
	setDescription setDescription
	setImage setImageFileExtension
	addOwners updateUserPermissions
	addAdmins updateUserPermissions
	addOrganisers updateUserPermissions
	addContributors updateUserPermissions
	addObservers updateUserPermissions
	removeUsers        updateUserPermissions
	get                get
	getInUserContext getInUserContext
	getInUserInviteContext getInUserContext
	search             search
	vada               vada.VadaClient
	log                golog.Log
}

func (ps *projectStore) Create(forUser string, name string, description string, imageUrl string) error {
	if err := ps.create(forUser, name, description, imageUrl); err != nil {
		ps.log.Error("ProjectStore.Create error: forUser: ", forUser, " name: '", name, "' description: '", description, "' imageUrl: '", imageUrl, "' error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.Create success: forUser: ", forUser, " name: '", name, "' description: '", description, "' imageUrl: '", imageUrl, "'")
	return nil
}

func (ps *projectStore) SetName(forUser string, id string, newName string) error {
	if err := ps.setName(forUser, id, newName); err != nil {
		ps.log.Error("ProjectStore.SetName error: forUser: ", forUser, " id: ", id, " newName: '", newName, "' error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.SetName success: forUser: ", forUser, " id: ", id, " newName: '", newName, "'")
	return nil
}

func (ps *projectStore) SetDescription(forUser string, id string, newDescription string) error {
	if err := ps.setDescription(forUser, id, newDescription); err != nil {
		ps.log.Error("ProjectStore.SetDescription error: forUser: ", forUser, " id: ", id, " newDescription: '", newDescription, "' error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.SetDescription success: forUser: ", forUser, " id: ", id, " newDescription: '", newDescription, "'")
	return nil
}

func (ps *projectStore) SetImage(forUser string, id string, name string, image multipart.File) error {
	if err := ps.setImage(forUser, id, newImageUrl); err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: ", forUser, " id: ", id, " newImageUrl: '", newImageUrl, "' error: ", err)
		return err
	}
	//TODO use vada client to upload new image file to project bucket
	ps.log.Info("ProjectStore.SetImage success: forUser: ", forUser, " id: ", id, " newImageUrl: '", newImageUrl, "'")
	return nil
}

func (ps *projectStore) AddOwners(forUser string, id string, users []string) error {
	if err := ps.addOwners(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddOwners error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.AddOwners success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) AddAdmins(forUser string, id string, users []string) error {
	if err := ps.addAdmins(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddAdmins error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.AddAdmins success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) AddOrganisers(forUser string, id string, users []string) error {
	if err := ps.addOrganisers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddOrganisers error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.AddOrganisers success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) AddContributors(forUser string, id string, users []string) error {
	if err := ps.addContributors(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddContributors error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.AddContributors success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) AddObservers(forUser string, id string, users []string) error {
	if err := ps.addObservers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddObservers error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.AddObservers success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) RemoveUsers(forUser string, id string, users []string) error {
	if err := ps.removeUsers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.RemoveUsers error: forUser: ", forUser, " id: ", id, " users: ", users, " error: ", err)
		return err
	}
	ps.log.Info("ProjectStore.RemoveUsers success: forUser: ", forUser, " id: ", id, " users: ", users)
	return nil
}

func (ps *projectStore) Get(forUser string, ids []string) ([]*project, error) {
	if projects, err := ps.get(forUser, ids); err != nil {
		ps.log.Error("ProjectStore.Get error: forUser: ", forUser, " ids: ", ids, " error: ", err)
		return projects, err
	} else {
		ps.log.Info("ProjectStore.Get success: forUser: ", forUser, " ids:", ids, " projects: ", projects)
		return projects, nil
	}
}

func (ps *projectStore) GetForUserWithRole(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
	if projects, totalResults, err := ps.getInUserContext(forUser, user, role, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.GetForCreator error: forUser: ", forUser, " creator: ", user, " error: ", err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.GetForCreator success: forUser: ", forUser, " creator: ", user, " total results found: ", totalResults, " projects: ", projects)
		return projects, totalResults, nil
	}
}

func (ps *projectStore) Search(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
	if projects, totalResults, err := ps.search(forUser, search, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.Search error: forUser: ", forUser, " search: '", search, "' offset: ", offset, " limit: ", limit, " sortBy: ", sortBy, " error: ", err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.Search success: forUser: ", forUser, " search: '", search, "' offset: ", offset, " limit: ", limit, " sortBy: ", sortBy, " total results found: ", totalResults, " projects: ", projects)
		return projects, totalResults, nil
	}
}
