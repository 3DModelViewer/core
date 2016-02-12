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
	userStore := NewSqlUserStore(db, log)

	cu, err := userStore.Login("dan autodeskId", "dan openId", "dan username", "dan avatar", "dan fullName", "dan email")
	b, _ := json.Marshal(cu)
	log.Info("%v %s %v", cu, string(b), err)

	err = userStore.SetDescription(cu.Id, "fuck you")
	log.Info("%v", err)

	us, err := userStore.Get([]string{cu.Id})
	b, _ = json.Marshal(us)
	log.Info("%v %s %v", us, string(b), err)

	fmt.Scanln()
}