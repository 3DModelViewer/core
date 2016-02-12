package user

import (
	"database/sql"
	"github.com/modelhub/db/api/project"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlUserStore(db *sql.DB, log golog.Log) UserStore {

	login := func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error) {
		rows, err := db.Query("CALL userLogin(?, ?, ?, ?, ?, ?)", autodeskId, openId, username, avatar, fullName, email)
		if err != nil {
			return nil, err
		}

		cu := CurrentUser{}

		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				err = rows.Scan(&cu.Id, &cu.Avatar, &cu.FullName, &cu.SuperUser, &cu.Description, &cu.UILanguage, &cu.UITheme, &cu.Locale, &cu.TimeFormat)
			}
		}

		return &cu, err
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
		if err != nil {
			return nil, err
		}

		users := make([]*UserWithDescription, 0, len(ids))

		if rows != nil {
			defer rows.Close()
			u := UserWithDescription{}
			for rows.Next() {
				tmpErr := rows.Scan(&u.Id, &u.Avatar, &u.FullName, &u.Description)
				if tmpErr != nil {
					err = tmpErr
				}
				users = append(users, &u)
			}
		}

		return users, err
	}

	_getInProjectContext := func(sql string, forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		rows, err := db.Query(sql, forUser, project, role, offset, limit, sortBy)
		if err != nil {
			return nil, 0, err
		}

		totalResults := 0
		users := make([]*UserInProjectContext, 0, 100)

		if rows != nil {
			defer rows.Close()
			u := UserInProjectContext{}
			for rows.Next() {
				tmpErr := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName, &u.Role)
				if tmpErr != nil {
					err = tmpErr
				}
				users = append(users, &u)
			}
		}

		return users, totalResults, err
	}

	getInProjectContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return _getInProjectContext("CALL userGetInProjectContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, sortBy)
	}

	getInProjectInviteContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return _getInProjectContext("CALL userGetInProjectInviteContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, sortBy)
	}

	search := func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
		rows, err := db.Query("CALL userSearch(?, ?, ?, ?)", search, offset, limit, sortBy)
		if err != nil {
			return nil, 0, err
		}

		totalResults := 0
		users := make([]*User, 0, 100)

		if rows != nil {
			defer rows.Close()
			u := User{}
			for rows.Next() {
				tmpErr := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName)
				if tmpErr != nil {
					err = tmpErr
				}
				users = append(users, &u)
			}
		}

		return users, totalResults, err
	}

	return newUserStore(login, setDescription, setUILanguage, setUITheme, setLocale, setTimeFormat, get, getInProjectContext, getInProjectInviteContext, search, log)
}
