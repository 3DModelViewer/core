package project

import(
	"mime/multipart"
)

type create func(forUser string, name string, description string, imageUrl string) error
type setName func(forUser string, id string, newName string) error
type setDescription func(forUser string, id string, newDescription string) error
type setImageFileExtension func(forUser string, id string, newImageFileExtension string) error
type updateUserPermissions func(forUser string, id string, users []string) error
type get func(forUser string, ids []string) ([]*project, error)
type getInUserContext func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error)
type search func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*project, int, error)

type ProjectStore interface {
	//writes
	Create(forUser string, name string, description string, imageUrl string) error
	SetName(forUser string, id string, newName string) error
	SetDescription(forUser string, id string, newDescription string) error
	setImage(forUser string, id string, name string, image multipart.File) error
	//permissions
	AddOwners(forUser string, id string, users []string) error
	AddAdmins(forUser string, id string, users []string) error
	AddOrganisers(forUser string, id string, users []string) error
	AddContributors(forUser string, id string, users []string) error
	AddObservers(forUser string, id string, users []string) error
	RemoveUsers(forUser string, id string, users []string) error
	AcceptInvitation(forUser string, project string)
	DeclineInvitation(forUser string, project string)
	//gets
	Get(forUser string, ids []string) ([]*project, error)
	GetInUserContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error)
	GetInUserInviteContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*project, int, error)
	Search(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*project, int, error)
}
