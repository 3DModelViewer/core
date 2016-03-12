package user

import (
	"database/sql"
	"errors"
	"github.com/modelhub/core/util"
	"github.com/robsix/golog"
	"strings"
)

func NewSqlUserStore(db *sql.DB, log golog.Log) UserStore {

	getterString := func(query string, args ...interface{}) (string, error) {
		str := ""
		rowsScan := func(rows *sql.Rows) error {
			if err := rows.Scan(&str); err != nil {
				return err
			}
			return nil
		}
		return str, util.SqlQuery(db, rowsScan, query, args...)
	}

	getterCurrentUser := func(query string, args ...interface{}) (*CurrentUser, error) {
		cu := CurrentUser{}
		rowsScan := func(rows *sql.Rows) error {
			if err := rows.Scan(&cu.Id, &cu.Avatar, &cu.FullName, &cu.SuperUser, &cu.UILanguage, &cu.UITheme, &cu.TimeFormat); err != nil {
				return err
			}
			return nil
		}
		return &cu, util.SqlQuery(db, rowsScan, query, args...)
	}

	getter := func(query string, colLen int, args ...interface{}) ([]*User, error) {
		us := make([]*User, 0, colLen)
		rowsScan := func(rows *sql.Rows) error {
			u := User{}
			if err := rows.Scan(&u.Id, &u.Avatar, &u.FullName); err != nil {
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

	login := func(autodeskId string, openId string, username string, avatar string, fullName string, email string) (string, error) {
		return getterString("CALL userLogin(?, ?, ?, ?, ?, ?)", autodeskId, openId, username, avatar, fullName, email)
	}

	getCurrent := func(id string) (*CurrentUser, error) {
		return getterCurrentUser("CALL userGetCurrent(?)", id)
	}

	setProperty := func(forUser string, property property, value string) error {
		var partialProcName string
		switch property {
		case Description:
			partialProcName = "Description"
		case UILanguage:
			partialProcName = "UILanguage"
		case UITheme:
			partialProcName = "UITheme"
		case TimeFormat:
			partialProcName = "TimeFormat"
		default:
			err := errors.New("invalid property name")
			return err
		}
		return util.SqlExec(db, "CALL userSet"+partialProcName+"(?, ?)", forUser, value)
	}

	get := func(ids []string) ([]*User, error) {
		return getter("CALL userGet(?)", len(ids), strings.Join(ids, ","))
	}

	search := func(search string, offset int, limit int, sortBy sortBy) ([]*User, int, error) {
		return offsetGetter("CALL userSearch(?, ?, ?, ?)", search, offset, limit, string(sortBy))
	}

	return newUserStore(login, getCurrent, setProperty, get, search, log)
}
