package main

import(
	"github.com/modelhub/core/user"
	"github.com/robsix/golog"
	"encoding/json"
	"github.com/modelhub/vada"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/documentversion"
	"time"
	"net/http"
	"io"
	"os"
	"github.com/modelhub/core"
)

const(
	vadaHost = "https://developer.api.autodesk.com"
	clientKey    = "vzZyhg9MZwhZhptG6JqCeR6gQorM8xvW"
	clientSecret = "Xc900b546fdb941f"
	ossBucketPrefix = "transient_01"
	ossBucketPolicy = vada.Transient
	sqlConnectionString = "modelhub-api:M0d-3l-Hu8-@p1@tcp(localhost:3306)/modelhub?parseTime=true&loc=UTC&multiStatements=true"
)
func main(){
	log := golog.NewConsoleLog(0)
	vada := vada.NewVadaClient(vadaHost, clientKey, clientSecret, log)
	ca, _ := core.NewSqlCoreApi(sqlConnectionString, vada, 5*time.Second, ossBucketPrefix, ossBucketPolicy, log)
	
	ashId, err := ca.User().Login("ash autodeskId", "ash openId", "ash username", "ash avatar", "ash fullName", "ash email")
	b, _ := json.Marshal(ashId)
	log.Info("%v %s %v", ashId, string(b), err)

	bobId, err := ca.User().Login("bob autodeskId", "bob openId", "bob username", "bob avatar", "bob fullName", "bob email")
	b, _ = json.Marshal(bobId)
	log.Info("%v %s %v", bobId, string(b), err)

	catId, err := ca.User().Login("cat autodeskId", "cat openId", "cat username", "cat avatar", "cat fullName", "cat email")
	b, _ = json.Marshal(catId)
	log.Info("%v %s %v", catId, string(b), err)

	err = ca.User().SetProperty(ashId, user.Description, "EDITED")
	log.Info("%v", err)

	uwds, err := ca.User().Get([]string{ashId, bobId, catId})
	b, _ = json.Marshal(uwds)
	log.Info("%v %s %v", uwds, string(b), err)

	us, totalResults, err := ca.User().Search("fullName", 0, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = ca.User().Search("fullName", 1, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = ca.User().Search("fullName", 2, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = ca.User().Search("fullName", 3, 5, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = ca.User().Search("fullName", 1, 1, user.FullNameAsc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	us, totalResults, err = ca.User().Search("fullName", 0, 5, user.FullNameDesc)
	b, _ = json.Marshal(us)
	log.Info("%v %d %s %v", us, totalResults, string(b), err)

	ashsProject, err := ca.Project().Create(ashId, "ashs project 1", "ash description 1", "", nil)
	b, _ = json.Marshal(ashsProject)
	log.Info("%v %d %s %v", ashsProject, totalResults, string(b), err)

	p, err := ca.Project().Create(ashId, "ashs project 2", "ash description 2", "", nil)
	b, _ = json.Marshal(p)
	log.Info("%v %d %s %v", p, totalResults, string(b), err)

	ps, totalResults, err := ca.Project().Search(ashId, "ashs", 0, 5, project.NameAsc)
	b, _ = json.Marshal(ps)
	log.Info("%v %d %s %v", ps, totalResults, string(b), err)

	sf1, _ := ca.TreeNode().CreateFolder(ashId, p.Id, "sub folder 1")
	sf2, _ := ca.TreeNode().CreateFolder(ashId, sf1.Id, "sub folder 2")
	_, _ = ca.TreeNode().CreateFolder(ashId, sf1.Id, "sub folder 3")

	parents, _ := ca.TreeNode().GetParents(ashId, sf2.Id)
	b, _ = json.Marshal(parents)
	log.Info("%v %s %v", parents, string(b), err)

	var doc *treenode.TreeNode
	var docVer *documentversion.DocumentVersion

	http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request){
		file, header, _ := r.FormFile("file")
		if doc == nil {
			doc, err = ca.TreeNode().CreateDocument(ashId, sf2.Id, header.Filename, "test comment blah", header.Filename, file)
			b, _ = json.Marshal(doc)
			log.Info("%v %s %v", doc, string(b), err)
			writeJson(w, doc)
		} else {
			docVer, err = ca.DocumentVersion().Create(ashId, doc.Id, "test comment 2 wahwah", header.Filename, file)
			b, _ = json.Marshal(docVer)
			log.Info("%v %s %v", docVer, string(b), err)
			writeJson(w, docVer)
		}
	})

	http.HandleFunc("/getDocVers", func(w http.ResponseWriter, r *http.Request){
		docVers, totalResults, err := ca.DocumentVersion().GetForDocument(ashId, doc.Id, 0, 10, documentversion.VersionAsc)
		b, _ = json.Marshal(docVers)
		log.Info("%d %v %s %v", totalResults, docVers, string(b), err)
		writeJson(w, docVers)
	})

	http.HandleFunc("/download", func(w http.ResponseWriter, r *http.Request){
		res, _ := ca.DocumentVersion().GetSeedFile(ashId, docVer.Id)
		if res != nil && res.Body != nil {
			defer res.Body.Close()
			io.Copy(w, res.Body)
		}
	})

	wd, _ := os.Getwd()
	fs := http.FileServer(http.Dir(wd))
	http.Handle("/", fs)

	log.Info("Server Listening on localhost:8080")
	http.ListenAndServe(":8080", nil)
}

func writeJson(w http.ResponseWriter, obj interface{}) error {
	js, err := json.Marshal(obj)
	w.Header().Set("Content-Type", "application/json")
	w.Write(js)
	return err
}