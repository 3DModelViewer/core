package project

import (
	"errors"
	"github.com/modelhub/core/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"io"
	"net/http"
)

func newProjectStore(create create, delete delete, setName setName, setDescription setDescription, setImageFileExtension setImageFileExtension, addUsers addUsers, removeUsers removeUsers, acceptInvite processInvite, declineInvite processInvite, getRole util.GetRole, get get, getInUserContext getInUserContext, getInUserInviteContext getInUserContext, search search, vada vada.VadaClient, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) ProjectStore {
	return &projectStore{
		create:                 create,
		delete:                 delete,
		setName:                setName,
		setDescription:         setDescription,
		setImageFileExtension:  setImageFileExtension,
		addUsers:               addUsers,
		removeUsers:            removeUsers,
		acceptInvite:           acceptInvite,
		declineInvite:          declineInvite,
		getRole:                getRole,
		get:                    get,
		getInUserContext:       getInUserContext,
		getInUserInviteContext: getInUserInviteContext,
		search:                 search,
		vada:                   vada,
		ossBucketPrefix:        ossBucketPrefix,
		ossBucketPolicy:        ossBucketPolicy,
		log:                    log,
	}
}

type projectStore struct {
	create                 create
	delete                 delete
	setName                setName
	setDescription         setDescription
	setImageFileExtension  setImageFileExtension
	addUsers               addUsers
	removeUsers            removeUsers
	acceptInvite           processInvite
	declineInvite          processInvite
	getRole                util.GetRole
	get                    get
	getInUserContext       getInUserContext
	getInUserInviteContext getInUserContext
	search                 search
	vada                   vada.VadaClient
	ossBucketPrefix        string
	ossBucketPolicy        vada.BucketPolicy
	log                    golog.Log
}

func (ps *projectStore) Create(forUser string, name string, description string, imageName string, image io.ReadCloser) (*Project, error) {
	newProjectId := util.NewId()
	var imageFileExtension string

	json, err := ps.vada.CreateBucket(ps.ossBucketPrefix+newProjectId, ps.ossBucketPolicy)
	if err != nil {
		ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageName: %q createBucketJson: %v error: %v", forUser, name, description, imageName, json, err)
		return nil, err
	}

	if image != nil {
		if imageFileExtension, err = util.GetImageFileExtension(imageName); err != nil {
			ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q error: %v", forUser, name, description, imageFileExtension, err)
		} else if json, err := ps.vada.UploadFile(newProjectId+"."+imageFileExtension, ps.ossBucketPrefix+newProjectId, image); err != nil {
			ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q imageUploadJson: %v error: %v", forUser, name, description, imageFileExtension, json, err)
			imageFileExtension = ""
		}
	}

	if proj, err := ps.create(forUser, newProjectId, name, description, imageFileExtension); err != nil {
		ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q image: %v error: %v", forUser, name, description, imageFileExtension, image, err)
		return proj, err
	} else {
		ps.log.Info("ProjectStore.Create success: forUser: %q name: %q description: %q imageFileExtension: %q", forUser, name, description, imageFileExtension)
		return proj, nil
	}
}

func (ps *projectStore) Delete(forUser string, id string) error {
	if err := ps.delete(forUser, id); err != nil {
		ps.log.Error("ProjectStore.Delete error: forUser: %q id: %q error: %v", forUser, id, err)
		return err
	}

	if err := ps.vada.DeleteBucket(ps.ossBucketPrefix + id); err != nil {
		ps.log.Error("ProjectStore.Delete error: forUser: %q id: %q error: %v", forUser, id, err)
	}

	ps.log.Info("ProjectStore.Delete success: forUser: %q id: %q", forUser, id)
	return nil
}

func (ps *projectStore) SetName(forUser string, id string, newName string) error {
	if err := ps.setName(forUser, id, newName); err != nil {
		ps.log.Error("ProjectStore.SetName error: forUser: %q id: %q newName: %q error: %v", forUser, id, newName, err)
		return err
	}
	ps.log.Info("ProjectStore.SetName success: forUser: %q id: %q newName: %q", forUser, id, newName)
	return nil
}

func (ps *projectStore) SetDescription(forUser string, id string, newDescription string) error {
	if err := ps.setDescription(forUser, id, newDescription); err != nil {
		ps.log.Error("ProjectStore.SetDescription error: forUser: %q id: %q newDescription: %q error: %v", forUser, id, newDescription, err)
		return err
	}
	ps.log.Info("ProjectStore.SetDescription success: forUser: %q id: %q newDescription: %q", forUser, id, newDescription)
	return nil
}

func (ps *projectStore) SetImage(forUser string, id string, name string, image io.ReadCloser) error {

	role, err := ps.getRole(forUser, id)
	if err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		return err
	} else if role != "owner" {
		err := errors.New("Unauthorized Action: none owner trying to set project image")
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		return err
	}

	if projects, err := ps.get(forUser, []string{id}); err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		return err
	} else if len(projects) != 1 {
		err := errors.New("project not found")
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		return err
	} else if projects[0].ImageFileExtension != "" {
		if err := ps.vada.DeleteFile(id+"."+projects[0].ImageFileExtension, ps.ossBucketPrefix+id); err != nil {
			ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		}
	}

	if image != nil {
		if imageFileExtension, err := util.GetImageFileExtension(name); err != nil {
			ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
			return err
		} else if json, err := ps.vada.UploadFile(id+"."+imageFileExtension, ps.ossBucketPrefix+id, image); err != nil {
			ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q imageFileExtension: %q image: %v imageUploadJson: %v error: %v", forUser, id, imageFileExtension, image, json, err)
			return err
		}
	}

	return nil
}

func (ps *projectStore) AddUsers(forUser string, id string, role Role, users []string) error {
	if err := ps.addUsers(forUser, id, role, users); err != nil {
		ps.log.Error("ProjectStore.AddUsers error: forUser: %q id: %q role: %q users: %v error: %v", forUser, id, role, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddUsers success: forUser: %q id: %q role: %q users: %v", forUser, id, role, users)
	return nil
}

func (ps *projectStore) RemoveUsers(forUser string, id string, users []string) error {
	if err := ps.removeUsers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.RemoveUsers error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.RemoveUsers success: forUser: %q id: %q users: %v", forUser, id, users)
	return nil
}

func (ps *projectStore) AcceptInvite(forUser string, id string) error {
	if err := ps.acceptInvite(forUser, id); err != nil {
		ps.log.Error("ProjectStore.AcceptInvite error: forUser: %q id: %q error: %v", forUser, id, err)
		return err
	}
	ps.log.Info("ProjectStore.AcceptInvite success: forUser: %q id: %q", forUser, id)
	return nil
}

func (ps *projectStore) DeclineInvite(forUser string, id string) error {
	if err := ps.declineInvite(forUser, id); err != nil {
		ps.log.Error("ProjectStore.DeclineInvite error: forUser: %q id: %q error: %v", forUser, id, err)
		return err
	}
	ps.log.Info("ProjectStore.DeclineInvite success: forUser: %q id: %q", forUser, id)
	return nil
}

func (ps *projectStore) GetRole(forUser string, id string) (string, error) {
	if role, err := ps.getRole(forUser, id); err != nil {
		ps.log.Error("ProjectStore.GetRole error: forUser: %q id: %q error: %v", forUser, id, err)
		return "", err
	} else {
		ps.log.Info("ProjectStore.GetRole success: forUser: %q id: %q role: %q", forUser, id, role)
		return role, nil
	}
}

func (ps *projectStore) GetImage(forUser string, id string) (*http.Response, error) {
	if projects, err := ps.get(forUser, []string{id}); err != nil || len(projects) == 0 {
		ps.log.Error("ProjectStore.GetImage error: forUser: %q id: %q error: %v", forUser, id, err)
		return nil, err
	} else if projects[0].ImageFileExtension == "" {
		err := errors.New("project has no image file")
		ps.log.Warning("ProjectStore.GetImage error: forUser: %q id: %q error: %v", forUser, id, err)
		return nil, err
	} else {
		if res, err := ps.vada.GetFile(id+"."+projects[0].ImageFileExtension, ps.ossBucketPrefix+id); err != nil {
			ps.log.Error("ProjectStore.GetImage error: forUser: %q id: %q error: %v", forUser, id, err)
			return res, err
		} else {
			ps.log.Info("ProjectStore.GetImage success: forUser: %q id: %q", forUser, id)
			return res, err
		}
	}
}

func (ps *projectStore) Get(forUser string, ids []string) ([]*Project, error) {
	if projects, err := ps.get(forUser, ids); err != nil {
		ps.log.Error("ProjectStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return projects, err
	} else {
		ps.log.Info("ProjectStore.Get success: forUser: %q ids: %v", forUser, ids)
		return projects, nil
	}
}

func (ps *projectStore) GetInUserContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error) {
	if projects, totalResults, err := ps.getInUserContext(forUser, user, role, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.GetInUserContext error: forUser: %q user: %q error: %v", forUser, user, err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.GetInUserContext success: forUser: %q user: %q totalResults: %d projects: %v", forUser, user, totalResults, projects)
		return projects, totalResults, nil
	}
}

func (ps *projectStore) GetInUserInviteContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error) {
	if projects, totalResults, err := ps.getInUserInviteContext(forUser, user, role, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.GetInUserInviteContext error: forUser: %q user: %q error: %v", forUser, user, err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.GetInUserInviteContext success: forUser: %q user: %q totalResults: %d projects: %v", forUser, user, totalResults, projects)
		return projects, totalResults, nil
	}
}

func (ps *projectStore) Search(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error) {
	if projects, totalResults, err := ps.search(forUser, search, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.Search error: forUser: %q search: %q offset: %d limit: %d sortBy: %q error: %v", forUser, search, offset, limit, sortBy, err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.Search success: forUser: %q search: %q offset: %d limit: %d sortBy: %q totalResults: %d projects: %v", forUser, search, offset, limit, sortBy, totalResults, projects)
		return projects, totalResults, nil
	}
}