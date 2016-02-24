package util

import (
	"database/sql"
)

func SqlExec(db *sql.DB, query string, args ...interface{}) error {
	_, err := db.Exec(query, args...)
	return err
}

func SqlQuery(db *sql.DB, rowsScan func(*sql.Rows) error, query string, args ...interface{}) error {
	rows, err := db.Query(query, args...)

	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			if err = rowsScan(rows); err != nil {
				return err
			}
		}
		return err
	}

	return err
}

func RowsContainsOnlyTotalResults(totalResults *int, rows *sql.Rows) bool {
	if cols, err := rows.Columns(); err == nil && len(cols) == 1 {
		err = rows.Scan(totalResults)
		return true
	}
	return false
}
