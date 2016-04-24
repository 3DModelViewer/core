package core

import (
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/helper"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/projectspaceversion"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/sheettransform"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/user"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"time"
	"github.com/modelhub/core/clashtest"
	"github.com/modelhub/caca"
)

func NewSqlCoreApi(mySqlConnection string, vada vada.VadaClient, caca caca.CacaClient, subTaskTimeout time.Duration, batchGetTimeout time.Duration, ossBucketPrefix string, ossBucketPolicy vada.BucketPolicy, log golog.Log) (CoreApi, error) {
	if db, err := sql.Open("mysql", mySqlConnection); err != nil {
		return nil, err
	} else {
		us := user.NewSqlUserStore(db, log)
		ps := project.NewSqlProjectStore(db, vada, ossBucketPrefix, ossBucketPolicy, log)
		tns := treenode.NewSqlTreeNodeStore(db, subTaskTimeout, vada, caca, ossBucketPrefix, log)
		dvs := documentversion.NewSqlDocumentVersionStore(db, subTaskTimeout, vada, ossBucketPrefix, log)
		psvs := projectspaceversion.NewSqlProjectSpaceVersionStore(db, subTaskTimeout, vada, caca, ossBucketPrefix, log)
		ss := sheet.NewSqlSheetStore(db, vada, log)
		sts := sheettransform.NewSqlSheetTransformStore(db, log)
		cts := clashtest.NewSqlClashTestStore(db, caca, log)
		h := helper.NewHelper(tns, dvs, psvs, ss, batchGetTimeout, log)
		return newCoreApi(us, ps, tns, dvs, psvs, ss, sts, cts, h)
	}
}
