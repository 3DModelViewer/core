package user

import (
	"github.com/modelhub/core/project"
)

type login func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error)
type getCurrent func(id string) (*CurrentUser, error)
type setProperty func(forUser string, property property, value string) error
type get func(ids []string) ([]*UserWithDescription, error)
type getInProjectContext func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error)
type search func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error)

type UserStore interface {
	Login(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error)
	GetCurrent(id string) (*CurrentUser, error)
	SetProperty(forUser string, property property, value string) error
	Get(ids []string) ([]*UserWithDescription, error)
	GetInProjectContext(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error)
	GetInProjectInviteContext(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error)
	Search(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error)
}
