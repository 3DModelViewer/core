package core

import (
	"database/sql"
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/user"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"time"
)

func NewSqlCoreApi(db *sql.DB, vada vada.VadaClient, statusCheckTimeout time.Duration, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) (CoreApi, error) {
	us := user.NewSqlUserStore(db, log)
	ps := project.NewSqlProjectStore(db, vada, ossBucketPrefix, ossBucketPolicy, log)
	tns := treenode.NewSqlTreeNodeStore(db, vada, ossBucketPrefix, log)
	dvs := documentversion.NewSqlDocumentVersionStore(db, statusCheckTimeout, vada, ossBucketPrefix, log)
	ss := sheet.NewSqlSheetStore(db, vada, log)
	return newCoreApi(us, ps, tns, dvs, ss)
}
