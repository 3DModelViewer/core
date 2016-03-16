package project

import (
	"io"
	"net/http"
)

type create func(forUser string, id, name string, thumbnailType string) (*Project, error)
type delete func(forUser string, id string) error
type setName func(forUser string, id string, newName string) error
type setDescription func(forUser string, id string, newDescription string) error
type setThumbnailType func(forUser string, id string, newThumbnailType string) error
type addUsers func(forUser string, id string, role role, users []string) error
type removeUsers func(forUser string, id string, users []string) error
type processInvite func(forUser string, id string) error
type getMemberships func(forUser string, id string, role role, offset int, limit int, sortBy sortBy) ([]*Membership, int, error)
type get func(forUser string, ids []string) ([]*Project, error)
type getInUserContext func(forUser string, user string, role role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
type search func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error)

type ProjectStore interface {
	//writes
	Create(forUser string, name string, thumbnailType string, thumbnail io.ReadCloser) (*Project, error)
	Delete(forUser string, id string) error
	SetName(forUser string, id string, newName string) error
	SetDescription(forUser string, id string, newDescription string) error
	SetThumbnail(forUser string, id string, thumbnailType string, thumbnail io.ReadCloser) error
	//permissions
	AddUsers(forUser string, id string, role role, users []string) error
	RemoveUsers(forUser string, id string, users []string) error
	AcceptInvite(forUser string, id string) error
	DeclineInvite(forUser string, id string) error
	GetRole(forUser string, id string) (string, error)
	GetMemberships(forUser string, id string, role role, offset int, limit int, sortBy sortBy) ([]*Membership, int, error)
	GetMembershipInvites(forUser string, id string, role role, offset int, limit int, sortBy sortBy) ([]*Membership, int, error)
	//gets
	GetThumbnail(forUser string, id string) (*http.Response, error)
	Get(forUser string, ids []string) ([]*Project, error)
	GetInUserContext(forUser string, user string, role role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
	GetInUserInviteContext(forUser string, user string, role role, offset int, limit int, sortBy sortBy) ([]*ProjectInUserContext, int, error)
	Search(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Project, int, error)
}
