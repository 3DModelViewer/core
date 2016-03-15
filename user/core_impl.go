package user

import (
	"github.com/robsix/golog"
)

func newUserStore(login login, getCurrent getCurrent, setProperty setProperty, get get, search search, log golog.Log) UserStore {
	return &userStore{
		login:       login,
		getCurrent:  getCurrent,
		setProperty: setProperty,
		get:         get,
		search:      search,
		log:         log,
	}
}

type userStore struct {
	login       login
	getCurrent  getCurrent
	setProperty setProperty
	get         get
	search      search
	log         golog.Log
}

func (us *userStore) Login(autodeskId string, openId string, username string, avatar string, fullName string, email string) (string, error) {
	if id, err := us.login(autodeskId, openId, username, avatar, fullName, email); err != nil {
		us.log.Error("UserStore.Login error: autodeskId: %q openId: %q username: %q avatar: %q fullName %q email: %q error: %v", autodeskId, openId, username, avatar, fullName, email, err)
		return id, err
	} else {
		us.log.Info("UserStore.Login success: autodeskId: %q openId: %q username: %q avatar: %q fullName %q email: %q", autodeskId, openId, username, avatar, fullName, email)
		return id, nil
	}
}

func (us *userStore) GetCurrent(id string) (*CurrentUser, error) {
	if currentUser, err := us.getCurrent(id); err != nil {
		us.log.Error("UserStore.GetCurrent error: id: %q error: %v", id, err)
		return currentUser, err
	} else {
		us.log.Info("UserStore.GetCurrent success: id: %q", id)
		return currentUser, nil
	}
}

func (us *userStore) SetProperty(forUser string, property property, value string) error {
	if err := us.setProperty(forUser, property, value); err != nil {
		us.log.Error("UserStore.SetProperty error: forUser: %q property: %q value: %q error: %v", forUser, property, value, err)
		return err
	} else {
		us.log.Info("UserStore.SetProperty success: forUser: %q property: %q value: %q", forUser, property, value)
		return nil
	}
}

func (us *userStore) Get(ids []string) ([]*User, error) {
	if users, err := us.get(ids); err != nil {
		us.log.Error("UserStore.Get error: ids: %v error: %v", ids, err)
		return users, err
	} else {
		us.log.Info("UserStore.Get success: ids: %v", ids)
		return users, nil
	}
}

func (us *userStore) Search(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
	if users, totalResults, err := us.search(search, offset, limit, sortBy); err != nil {
		us.log.Error("UserStore.Search error: search: %q offset: %d limit: %d sortBy: %q error: %v", search, offset, limit, sortBy, err)
		return users, totalResults, err
	} else {
		us.log.Info("UserStore.Search success: search: %q offset: %d limit: %d sortBy: %q totalResults: %d", search, offset, limit, sortBy, totalResults)
		return users, totalResults, nil
	}
}
