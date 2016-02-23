package user

import (
	"database/sql"
	"github.com/modelhub/core/api/project"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlUserStore(db *sql.DB, log golog.Log) UserStore {

	login := func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error) {
		rows, err := db.Query("CALL userLogin(?, ?, ?, ?, ?, ?)", autodeskId, openId, username, avatar, fullName, email)

		if rows != nil {
			defer rows.Close()
			cu := CurrentUser{}
			for rows.Next() {
				if err := rows.Scan(&cu.Id, &cu.Avatar, &cu.FullName, &cu.SuperUser, &cu.Description, &cu.UILanguage, &cu.UITheme, &cu.Locale, &cu.TimeFormat); err != nil {
					return &cu, err
				}
			}
			return &cu, err
		}

		return nil, err
	}

	setProperty := func(sql string, forUser string, value string) error {
		_, err := db.Exec(sql, forUser, value)
		return err
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

	get := func(ids []string) ([]*UserWithDescription, error) {
		rows, err := db.Query("CALL userGet(?)", strings.Join(ids, ","))

		if rows != nil {
			defer rows.Close()
			us := make([]*UserWithDescription, 0, len(ids))
			for rows.Next() {
				u := UserWithDescription{}
				if err := rows.Scan(&u.Id, &u.Avatar, &u.FullName, &u.Description); err != nil {
					return us, err
				}
				us = append(us, &u)
			}
			return us, err
		}

		return nil, err
	}

	_getInProjectContext := func(sql string, forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		rows, err := db.Query(sql, forUser, project, role, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			totalResults := 0
			users := make([]*UserInProjectContext, 0, 100)
			for rows.Next() {
				u := UserInProjectContext{}
				if err := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName, &u.Role); err != nil {
					return users, totalResults, err
				}
				users = append(users, &u)
			}
			return users, totalResults, err
		}

		return nil, 0, err
	}

	getInProjectContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return _getInProjectContext("CALL userGetInProjectContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, sortBy)
	}

	getInProjectInviteContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return _getInProjectContext("CALL userGetInProjectInviteContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, sortBy)
	}

	search := func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
		rows, err := db.Query("CALL userSearch(?, ?, ?, ?)", search, offset, limit, string(sortBy))

		if rows != nil {
			defer rows.Close()
			totalResults := 0
			users := make([]*User, 0, 100)
			for rows.Next() {
				u := User{}
				if err := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName); err != nil {
					return users, totalResults, err
				}
				users = append(users, &u)
			}
			return users, totalResults, err
		}

		return nil, 0, err
	}

	return newUserStore(login, setDescription, setUILanguage, setUITheme, setLocale, setTimeFormat, get, getInProjectContext, getInProjectInviteContext, search, log)
}
