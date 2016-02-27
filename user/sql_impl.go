package user

import (
	"database/sql"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/util"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlUserStore(db *sql.DB, log golog.Log) UserStore {

	getterCurrentUser := func(query string, args ...interface{}) (*CurrentUser, error) {
		cu := CurrentUser{}
		rowsScan := func(rows *sql.Rows) error {
			if err := rows.Scan(&cu.Id, &cu.Avatar, &cu.FullName, &cu.SuperUser, &cu.Description, &cu.UILanguage, &cu.UITheme, &cu.Locale, &cu.TimeFormat); err != nil {
				return err
			}
			return nil
		}
		return &cu, util.SqlQuery(db, rowsScan, query, args...)
	}

	getter := func(query string, colLen int, args ...interface{}) ([]*UserWithDescription, error) {
		us := make([]*UserWithDescription, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			u := UserWithDescription{}
			if err := rows.Scan(&u.Id, &u.Avatar, &u.FullName, &u.Description); err != nil {
				return err
			}
			us = append(us, &u)
			return nil
		}
		return us, util.SqlQuery(db, rowsScan, query, args...)
	}

	offsetGetter := func(query string, args ...interface{}) ([]*User, int, error) {
		us := make([]*User, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			u := User{}
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			if err := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName); err != nil {
				return err
			}
			us = append(us, &u)
			return nil
		}
		return us, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	offsetGetterInProjectContext := func(query string, args ...interface{}) ([]*UserInProjectContext, int, error) {
		us := make([]*UserInProjectContext, 0, util.DefaultSqlOffsetQueryLimit)
		totalResults := 0
		rowsScan := func(rows *sql.Rows) error {
			u := UserInProjectContext{}
			if util.RowsContainsOnlyTotalResults(&totalResults, rows) {
				return nil
			}
			if err := rows.Scan(&totalResults, &u.Id, &u.Avatar, &u.FullName, &u.Role); err != nil {
				return err
			}
			us = append(us, &u)
			return nil
		}
		return us, totalResults, util.SqlQuery(db, rowsScan, query, args...)
	}

	login := func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (*CurrentUser, error) {
		return getterCurrentUser("CALL userLogin(?, ?, ?, ?, ?, ?)", autodeskId, openId, username, avatar, fullName, email)
	}

	getCurrent := func(id string) (*CurrentUser, error) {
		return getterCurrentUser("CALL userGetCurrent(?)", id)
	}

	setDescription := func(forUser string, description string) error {
		return util.SqlExec(db, "CALL userSetDescription(?, ?)", forUser, description)
	}

	setUILanguage := func(forUser string, uiLanguage string) error {
		return util.SqlExec(db, "CALL userSetUILanguage(?, ?)", forUser, uiLanguage)
	}

	setUITheme := func(forUser string, uiTheme string) error {
		return util.SqlExec(db, "CALL userSetUITheme(?, ?)", forUser, uiTheme)
	}

	setLocale := func(forUser string, locale string) error {
		return util.SqlExec(db, "CALL userSetLocale(?, ?)", forUser, locale)
	}

	setTimeFormat := func(forUser string, timeFormat string) error {
		return util.SqlExec(db, "CALL userSetTimeFormat(?, ?)", forUser, timeFormat)
	}

	get := func(ids []string) ([]*UserWithDescription, error) {
		return getter("CALL userGet(?)", len(ids), strings.Join(ids, ","))
	}

	getInProjectContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return offsetGetterInProjectContext("CALL userGetInProjectContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, string(sortBy))
	}

	getInProjectInviteContext := func(forUser string, project string, role project.Role, offset int, limit int, sortBy sortBy) ([]*UserInProjectContext, int, error) {
		return offsetGetterInProjectContext("CALL userGetInProjectInviteContext(?, ?, ?, ?, ?, ?)", forUser, project, role, offset, limit, string(sortBy))
	}

	search := func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
		return offsetGetter("CALL userSearch(?, ?, ?, ?)", search, offset, limit, string(sortBy))
	}

	return newUserStore(login, getCurrent, setDescription, setUILanguage, setUITheme, setLocale, setTimeFormat, get, getInProjectContext, getInProjectInviteContext, search, log)
}
