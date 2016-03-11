package user

type login func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (string, error)
type getCurrent func(id string) (*CurrentUser, error)
type setProperty func(forUser string, property property, value string) error
type get func(ids []string) ([]*User, error)
type search func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error)

type UserStore interface {
	Login(autodeskId string, openId string, username string, avatar string, fullName string, email string) (string, error)
	GetCurrent(id string) (*CurrentUser, error)
	SetProperty(forUser string, property property, value string) error
	Get(ids []string) ([]*User, error)
	Search(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error)
}
