package main

import(
	"github.com/modelhub/db/api/user"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/robsix/golog"
	"fmt"
	"encoding/json"
	"github.com/modelhub/vada"
	"github.com/modelhub/db/api/project"
	"github.com/modelhub/db/api/treenode"
	"github.com/modelhub/db/api/documentversion"
)

const(
	vadaHost = "https://developer.api.autodesk.com"
	clientKey    = "vzZyhg9MZwhZhptG6JqCeR6gQorM8xvW"
	clientSecret = "Xc900b546fdb941f"
	ossBucketPrefix = "transient_01"
	ossBucketPolicy = vada.Transient
	sqlDriver = "mysql"
	sqlConnectionString = "modelhub-api:M0d-3l-Hu8-@p1@tcp(localhost:3306)/modelhub?parseTime=true&loc=UTC"
)
func main(){
	log := golog.NewConsoleLog(0)
	vada := vada.NewVadaClient(vadaHost, clientKey, clientSecret, log)
	db, _ := sql.Open(sqlDriver, sqlConnectionString)
	userStore := user.NewSqlUserStore(db, log)
	projectStore := project.NewSqlProjectStore(db, vada, ossBucketPrefix, ossBucketPolicy, log)
	treeNodeStore := treenode.NewSqlTreeNodeStore(db, vada, ossBucketPrefix, log)
	documentversion.NewSqlDocumentVersionStore(db, vada, ossBucketPrefix, log)

	ash, err := userStore.Login("ash autodeskId", "ash openId", "ash username", "ash avatar", "ash fullName", "ash email")
	b, _ := json.Marshal(ash)
	log.Info("%v %s %v", ash, string(b), err)

	bob, err := userStore.Login("bob autodeskId", "bob openId", "bob username", "bob avatar", "bob fullName", "bob email")
	b, _ = json.Marshal(bob)
	log.Info("%v %s %v", bob, string(b), err)

	cat, err := userStore.Login("cat autodeskId", "cat openId", "cat username", "cat avatar", "cat fullName", "cat email")
	b, _ = json.Marshal(cat)
	log.Info("%v %s %v", cat, string(b), err)

	err = userStore.SetDescription(ash.Id, "EDITED")
	log.Info("%v", err)

	uwds, err := userStore.Get([]string{ash.Id, bob.Id, cat.Id})
	b, _ = json.Marshal(uwds)
	log.Info("%v %s %v", uwds, string(b), err)

	us, totalResults, err := userStore.Search("fullName", 0, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = userStore.Search("fullName", 1, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = userStore.Search("fullName", 2, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

//	us, totalResults, err = userStore.Search("fullName", 3, 5, FullNameAsc)
//	b, _ = json.Marshal(us)
//	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = userStore.Search("fullName", 1, 1, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = userStore.Search("fullName", 0, 5, user.FullNameDec)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	p, err := projectStore.Create(ash.Id, "ashs project 1", "ash description 1", "", nil)
	b, _ = json.Marshal(p)
	log.Info("%v %d %s %v", p, totalResults, string(b), err)

	p, err = projectStore.Create(ash.Id, "ashs project 2", "ash description 2", "", nil)
	b, _ = json.Marshal(p)
	log.Info("%v %d %s %v", p, totalResults, string(b), err)

	ps, totalResults, err := projectStore.Search(ash.Id, "ashs", 0, 5, project.NameAsc)
	b, _ = json.Marshal(ps)
	log.Info("%v %d %s %v", ps, totalResults, string(b), err)

	sf1, _ := treeNodeStore.CreateFolder(ash.Id, p.Id, "sub folder 1")
	sf2, _ := treeNodeStore.CreateFolder(ash.Id, sf1.Id, "sub folder 2")
	_, _ = treeNodeStore.CreateFolder(ash.Id, sf1.Id, "sub folder 3")

	parents, _ := treeNodeStore.GetParents(ash.Id, sf2.Id)
	b, _ = json.Marshal(parents)
	log.Info("%v %s %v", parents, string(b), err)

	fmt.Scanln()
}