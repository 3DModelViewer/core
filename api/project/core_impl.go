package project

import (
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"mime/multipart"
	"strings"
)

func newProjectStore(create create, delete delete, setName setName, setDescription setDescription, setImageFileExtension setImageFileExtension, addOwners updateUserPermissions, addAdmins updateUserPermissions, addOrganisers updateUserPermissions, addContributors updateUserPermissions, addObservers updateUserPermissions, removeUsers updateUserPermissions, acceptInvitation processInvitation, declineInvitation processInvitation, get get, getInUserContext getInUserContext, getInUserInviteContext getInUserContext, search search, vada vada.VadaClient, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) ProjectStore {
	return &projectStore{
		create:                 create,
		delete:                 delete,
		setName:                setName,
		setDescription:         setDescription,
		setImageFileExtension:               setImageFileExtension,
		addOwners:              addOwners,
		addAdmins:              addAdmins,
		addOrganisers:          addOrganisers,
		addContributors:        addContributors,
		addObservers:           addObservers,
		removeUsers:            removeUsers,
		acceptInvitation: acceptInvitation,
		declineInvitation: declineInvitation,
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
	addOwners              updateUserPermissions
	addAdmins              updateUserPermissions
	addOrganisers          updateUserPermissions
	addContributors        updateUserPermissions
	addObservers           updateUserPermissions
	removeUsers            updateUserPermissions
	acceptInvitation       processInvitation
	declineInvitation      processInvitation
	get                    get
	getInUserContext       getInUserContext
	getInUserInviteContext getInUserContext
	search                 search
	vada                   vada.VadaClient
	ossBucketPrefix        string
	ossBucketPolicy        vada.BucketPolicy
	log                    golog.Log
}

func (ps *projectStore) Create(forUser string, name string, description string, imageName string, image multipart.File) (*project, error) {
	imageFileExtension, err := getImageFileExtension(imageName)
	if err != nil && image != nil {
		ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageName: %q image: %v error: %v", forUser, name, description, imageName, image, err)
		return nil, err
	}

	proj, err := ps.create(forUser, name, description, imageFileExtension)
	if err != nil {
		ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q image: %v error: %v", forUser, name, description, imageFileExtension, image, err)
		return proj, err
	}

	json, err := ps.vada.CreateBucket(ps.ossBucketPrefix+proj.Id, ps.ossBucketPolicy)
	if err != nil {
		ps.delete(forUser, proj.Id)
		ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q image: %v createBucketJson: %v error: %v", forUser, name, description, imageFileExtension, image, json, err)
		return proj, err
	}

	if image != nil {
		if json, err := ps.vada.UploadFile(proj.Id+"."+imageFileExtension, ps.ossBucketPrefix+proj.Id, image); err != nil {
			ps.log.Error("ProjectStore.Create error: forUser: %q name: %q description: %q imageFileExtension: %q image: %v imageUploadJson: %v error: %v", forUser, name, description, imageFileExtension, image, json, err)
			ps.setImageFileExtension(forUser, proj.Id, "")
		}
	}

	ps.log.Info("ProjectStore.Create success: forUser: %q name: %q description: %q imageFileExtension: %q image: %v error: %v", forUser, name, description, imageFileExtension, image, err)
	return proj, nil
}

func (ps *projectStore) Delete(forUser string, id string) error {
	if err := ps.delete(forUser, id); err != nil {
		ps.log.Error("ProjectStore.Delete error: forUser: %q id: %q error: %v", forUser, id, err)
		return err
	}

	if err := ps.vada.DeleteBucket(ps.ossBucketPrefix+id); err != nil {
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

func (ps *projectStore) SetImage(forUser string, id string, name string, image multipart.File) error {
	imageFileExtension, err := getImageFileExtension(name)
	if err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q name: %q image: %v error: %v", forUser, id, name, image, err)
		return err
	}

	if err := ps.setImageFileExtension(forUser, id, imageFileExtension); err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q imageFileExtension: %q image: %v error: %v", forUser, id, imageFileExtension, err)
		return err
	}

	if json, err := ps.vada.UploadFile(id+"."+imageFileExtension, ps.ossBucketPrefix+id, image); err != nil {
		ps.log.Error("ProjectStore.SetImage error: forUser: %q id: %q imageFileExtension: %q image: %v imageUploadJson: %v error: %v", forUser, id, imageFileExtension, image, json, err)
		ps.setImageFileExtension(forUser, id, "")
		return err
	}

	ps.log.Info("ProjectStore.SetImage success: forUser: %q id: %q imageFileExtension: %q image: %v", forUser, id, imageFileExtension, image)
	return nil
}

func (ps *projectStore) AddOwners(forUser string, id string, users []string) error {
	if err := ps.addOwners(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddOwners error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddOwners success: forUser: %q id: %q users: %v", forUser, id, users)
	return nil
}

func (ps *projectStore) AddAdmins(forUser string, id string, users []string) error {
	if err := ps.addAdmins(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddAdmins error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddAdmins success: forUser: %q id: %q users: %v", forUser, id, users)
	return nil
}

func (ps *projectStore) AddOrganisers(forUser string, id string, users []string) error {
	if err := ps.addOrganisers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddOrganisers error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddOrganisers success: forUser: %q id: %q users: %v", forUser, id, users)
	return nil
}

func (ps *projectStore) AddContributors(forUser string, id string, users []string) error {
	if err := ps.addContributors(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddContributors error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddContributors success: forUser: %q id: %q users: %v", forUser, id, users)
	return nil
}

func (ps *projectStore) AddObservers(forUser string, id string, users []string) error {
	if err := ps.addObservers(forUser, id, users); err != nil {
		ps.log.Error("ProjectStore.AddObservers error: forUser: %q id: %q users: %v error: %v", forUser, id, users, err)
		return err
	}
	ps.log.Info("ProjectStore.AddObservers success: forUser: %q id: %q users: %v", forUser, id, users)
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

func (ps *projectStore) AcceptInvitation(forUser string, project string) error {
	if err := ps.acceptInvitation(forUser, project); err != nil {
		ps.log.Error("ProjectStore.RemoveUsers error: forUser: %q project: %q error: %v", forUser, project, err)
		return err
	}
	ps.log.Info("ProjectStore.RemoveUsers success: forUser: %q project: %q", forUser, project)
	return nil
}

func (ps *projectStore) DeclineInvitation(forUser string, project string) error {
	if err := ps.declineInvitation(forUser, project); err != nil {
		ps.log.Error("ProjectStore.DeclineInvitation error: forUser: %q project: %q error: %v", forUser, project, err)
		return err
	}
	ps.log.Info("ProjectStore.DeclineInvitation success: forUser: %q project: %q", forUser, project)
	return nil
}

func (ps *projectStore) Get(forUser string, ids []string) ([]*project, error) {
	if projects, err := ps.get(forUser, ids); err != nil {
		ps.log.Error("ProjectStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return projects, err
	} else {
		ps.log.Info("ProjectStore.Get success: forUser: %q ids: %v", forUser, ids)
		return projects, nil
	}
}

func (ps *projectStore) GetInUserContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
	if projects, totalResults, err := ps.getInUserContext(forUser, user, role, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.GetInUserContext error: forUser: %q user: %q error: %v", forUser, user, err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.GetInUserContext success: forUser: %q user: %q totalResults: %d projects: %v", forUser, user, totalResults, projects)
		return projects, totalResults, nil
	}
}

func (ps *projectStore) GetInUserInviteContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error) {
	if projects, totalResults, err := ps.getInUserInviteContext(forUser, user, role, offset, limit, sortBy); err != nil {
		ps.log.Error("ProjectStore.GetInUserInviteContext error: forUser: %q user: %q error: %v", forUser, user, err)
		return projects, totalResults, err
	} else {
		ps.log.Info("ProjectStore.GetInUserInviteContext success: forUser: %q user: %q totalResults: %d projects: %v", forUser, user, totalResults, projects)
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

func getImageFileExtension(imageName string) (string, error) {
	switch {
	case strings.HasSuffix(imageName, ".png"):
		return "png", nil
	case strings.HasSuffix(imageName, ".jpeg"):
		return "jpeg", nil
	case strings.HasSuffix(imageName, ".jpg"):
		return "jpg", nil
	case strings.HasSuffix(imageName, ".gif"):
		return "gif", nil
	case strings.HasSuffix(imageName, ".webp"):
		return "webp", nil
	}
	return "", &cantFindValidImageFileExtensionError{imageName}
}
