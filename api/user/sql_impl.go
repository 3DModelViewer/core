package user

import (
	"database/sql"
	"github.com/robsix/golog"
	"github.com/modelhub/db/api/project"
)

func NewSqlUserStore(db *sql.DB, log golog.Log) UserStore {
	login := func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error) {
		return nil, nil
	}

	setProperty := func(sql string, forUser string, value string) error {
		return nil
	}

	setDescription := func(forUser string, description string) error {
		return setProperty("CALL userSetDescription(?, ?)", forUser, description)
	}

	setUILanguage := func(forUser string, uiLanguage string) error {
		return setProperty("CALL userSetUILanguage(?, ?)", forUser, uiLanguage)
	}

	setUITheme := func(forUser string, uiTheme string) error {
		return setProperty("CALL userSetUITheme(?, ?)", forUser, uiTheme)
	}

	setLocale := func(forUser string, locale string) error {
		return setProperty("CALL userSetLocale(?, ?)", forUser, locale)
	}

	setTimeFormat := func(forUser string, timeFormat string) error {
		return setProperty("CALL userSetTimeFormat(?, ?)", forUser, timeFormat)
	}

	get := func(ids []string) ([]*User, error) {
		return nil, nil
	}

	getInProjectContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return nil, 0, nil
	}

	getInProjectInviteContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return nil, 0, nil
	}

	search := func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
		return nil, 0, nil
	}

	return newUserStore(login, setDescription, setUILanguage, setUITheme, setLocale, setTimeFormat, get, getInProjectContext, getInProjectInviteContext, search, log)
}
