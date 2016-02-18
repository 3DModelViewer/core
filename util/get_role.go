package util

import (
	"database/sql"
)

type GetRole func(forUser string, id string) (string, error)

func GetRoleFunc(db *sql.DB) GetRole {
	return func(forUser string, projectId string) (string, error) {
		rows, err := db.Query("CALL projectGetRole(?, ?)", forUser, projectId)

		if rows != nil {
			defer rows.Close()
			role := ""
			for rows.Next() {
				if err := rows.Scan(&role); err != nil {
					return role, err
				}
			}
			return role, err
		}

		return "", err
	}
}
