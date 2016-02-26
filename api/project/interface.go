package project

import (
	"io"
	"net/http"
)

type create func(forUser string, id, name string, description string, imageFileExtension string) (*Project, error)
type delete func(forUser string, id string) error
type setName func(forUser string, id string, newName string) error
type setDescription func(forUser string, id string, newDescription string) error
type setImageFileExtension func(forUser string, id string, newImageFileExtension string) error
type addUsers func(forUser string, id string, role Role, users []string) error
type removeUsers func(forUser string, id string, users []string) error
type processInvitation func(forUser string, id string) error
type get func(forUser string, ids []string) ([]*Project, error)
type getInUserContext func(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
type search func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error)

type ProjectStore interface {
	//writes
	Create(forUser string, name string, description string, imageName string, image io.ReadCloser) (*Project, error)
	Delete(forUser string, id string) error
	SetName(forUser string, id string, newName string) error
	SetDescription(forUser string, id string, newDescription string) error
	SetImage(forUser string, id string, name string, image io.ReadCloser) error
	//permissions
	AddUsers(forUser string, id string, role Role, users []string) error
	RemoveUsers(forUser string, id string, users []string) error
	AcceptInvitation(forUser string, id string) error
	DeclineInvitation(forUser string, id string) error
	GetRole(forUser string, id string) (string, error)
	//gets
	GetImage(forUser string, id string) (*http.Response, error)
	Get(forUser string, ids []string) ([]*Project, error)
	GetInUserContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
	GetInUserInviteContext(forUser string, user string, role Role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
	Search(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error)
}
