package main

import(
	. "github.com/modelhub/db/api/user"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/robsix/golog"
	"fmt"
	"encoding/json"
)

func main(){
	log := golog.NewConsoleLog(0)
	db, _ := sql.Open("mysql", "modelhub-api:M0d-3l-Hu8-@p1@tcp(localhost:3306)/modelhub?parseTime=true&loc=UTC")

	rows, err := db.Query("CALL userLogin(?,?,?,?,?,?)", "dan autodeskId", "dan openId", "dan username", "dan avatar", "dan fullName", "dan email")

	log.Error("%v %v",rows, err)
	cu := CurrentUser{}

	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			err = rows.Scan(&cu.Id, &cu.Avatar, &cu.FullName, &cu.SuperUser, &cu.Description, &cu.UILanguage, &cu.UITheme, &cu.TimeZone, &cu.TimeFormat)
		}
		log.Critical("ITER %v", err)
	}

	log.Info("%#v", cu)
	b, err := json.Marshal(&cu)
	log.Info("%q", string(b))

	NewSqlUserStore(db, log)

	fmt.Scanln()
}