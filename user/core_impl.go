package user

import (
	"github.com/modelhub/core/project"
	"github.com/robsix/golog"
)

func newUserStore(login login, getCurrent getCurrent, setDescription setProperty, setUILanguage setProperty, setUITheme setProperty, setLocale setProperty, setTimeFormat setProperty, get get, getInProjectContext getInProjectContext, getInProjectInviteContext getInProjectContext, search search, log golog.Log) UserStore {
	return &userStore{
		login:                     login,
		getCurrent:                getCurrent,
		setDescription:            setDescription,
		setUILanguage:             setUILanguage,
		setUITheme:                setUITheme,
		setLocale:                 setLocale,
		setTimeFormat:             setTimeFormat,
		get:                       get,
		getInProjectContext:       getInProjectContext,
		getInProjectInviteContext: getInProjectInviteContext,
		search: search,
		log:    log,
	}
}

type userStore struct {
	login                     login
	getCurrent                getCurrent
	setDescription            setProperty
	setUILanguage             setProperty
	setUITheme                setProperty
	setLocale                 setProperty
	setTimeFormat             setProperty
	get                       get
	getInProjectContext       getInProjectContext
	getInProjectInviteContext getInProjectContext
	search                    search
	log                       golog.Log
}

func (us *userStore) Login(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error) {
	if currentUser, err := us.login(autodeskId, openId, username, avatar, fullName, email); err != nil {
		us.log.Error("UserStore.Login error: autodeskId: %q openId: %q username: %q avatar: %q fullName %q email: %q error: %v", autodeskId, openId, username, avatar, fullName, email, err)
		return currentUser, err
	} else {
		us.log.Info("UserStore.Login success: autodeskId: %q openId: %q username: %q avatar: %q fullName %q email: %q", autodeskId, openId, username, avatar, fullName, email)
		return currentUser, nil
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

func (us *userStore) SetDescription(forUser string, description string) error {
	if err := us.setDescription(forUser, description); err != nil {
		us.log.Error("UserStore.SetDescription error: forUser: %q description: %q error: %v", forUser, description, err)
		return err
	} else {
		us.log.Info("UserStore.SetDescription success: forUser: %q description: %q", forUser, description)
		return nil
	}
}

func (us *userStore) SetUILanguage(forUser string, uiLanguage string) error {
	if err := us.setUILanguage(forUser, uiLanguage); err != nil {
		us.log.Error("UserStore.SetUILanguage error: forUser: %q uiLanguage: %q error: %v", forUser, uiLanguage, err)
		return err
	} else {
		us.log.Info("UserStore.SetUILanguage success: forUser: %q uiLanguage: %q", forUser, uiLanguage)
		return nil
	}
}

func (us *userStore) SetUITheme(forUser string, uiTheme string) error {
	if err := us.setUITheme(forUser, uiTheme); err != nil {
		us.log.Error("UserStore.SetUITheme error: forUser: %q uiTheme: %q error: %v", forUser, uiTheme, err)
		return err
	} else {
		us.log.Info("UserStore.SetUITheme success: forUser: %q uiTheme: %q", forUser, uiTheme)
		return nil
	}
}

func (us *userStore) SetLocale(forUser string, locale string) error {
	if err := us.setLocale(forUser, locale); err != nil {
		us.log.Error("UserStore.SetLocale error: forUser: %q locale: %q error: %v", forUser, locale, err)
		return err
	} else {
		us.log.Info("UserStore.SetLocale success: forUser: %q locale: %q", forUser, locale)
		return nil
	}
}

func (us *userStore) SetTimeFormat(forUser string, timeFormat string) error {
	if err := us.setTimeFormat(forUser, timeFormat); err != nil {
		us.log.Error("UserStore.SetTimeFormat error: forUser: %q timeFormat: %q error: %v", forUser, timeFormat, err)
		return err
	} else {
		us.log.Info("UserStore.SetTimeFormat success: forUser: %q timeFormat: %q", forUser, timeFormat)
		return nil
	}
}

func (us *userStore) Get(ids []string) ([]*UserWithDescription, error) {
	if users, err := us.get(ids); err != nil {
		us.log.Error("UserStore.Get error: ids: %v error: %v", ids, err)
		return users, err
	} else {
		us.log.Info("UserStore.Get success: ids: %v", ids)
		return users, nil
	}
}

func (us *userStore) GetInProjectContext(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
	if users, totalResults, err := us.getInProjectContext(forUser, project, role, offset, limit, sortBy); err != nil {
		us.log.Error("UserStore.GetInProjectContext error: forUser: %q project: %q role: %q offset: %d limit: %d sortBy: %q error: %v", forUser, project, role, offset, limit, sortBy, err)
		return users, totalResults, err
	} else {
		us.log.Info("UserStore.GetInProjectContext success: forUser: %q project: %q role: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, project, role, offset, limit, sortBy, totalResults)
		return users, totalResults, nil
	}
}

func (us *userStore) GetInProjectInviteContext(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
	if users, totalResults, err := us.getInProjectInviteContext(forUser, project, role, offset, limit, sortBy); err != nil {
		us.log.Error("UserStore.GetInProjectInviteContext error: forUser: %q project: %q role: %q offset: %d limit: %d sortBy: %q error: %v", forUser, project, role, offset, limit, sortBy, err)
		return users, totalResults, err
	} else {
		us.log.Info("UserStore.GetInProjectInviteContext success: forUser: %q project: %q role: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, project, role, offset, limit, sortBy, totalResults)
		return users, totalResults, nil
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
