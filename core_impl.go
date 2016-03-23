package core

import (
	"errors"
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/user"
	"github.com/modelhub/core/helper"
)

func newCoreApi(us user.UserStore, ps project.ProjectStore, tns treenode.TreeNodeStore, dvs documentversion.DocumentVersionStore, ss sheet.SheetStore, h helper.Helper) (CoreApi, error) {
	if us == nil || ps == nil || tns == nil || dvs == nil || ss == nil {
		return nil, errors.New("nil values to CoreApi parameters or not allowed")
	}
	return &coreApi{
		us:  us,
		ps:  ps,
		tns: tns,
		dvs: dvs,
		ss:  ss,
		h: h,
	}, nil
}

type coreApi struct {
	us  user.UserStore
	ps  project.ProjectStore
	tns treenode.TreeNodeStore
	dvs documentversion.DocumentVersionStore
	ss  sheet.SheetStore
	h helper.Helper
}

func (ca *coreApi) User() user.UserStore {
	return ca.us
}

func (ca *coreApi) Project() project.ProjectStore {
	return ca.ps
}

func (ca *coreApi) TreeNode() treenode.TreeNodeStore {
	return ca.tns
}

func (ca *coreApi) DocumentVersion() documentversion.DocumentVersionStore {
	return ca.dvs
}

func (ca *coreApi) Sheet() sheet.SheetStore {
	return ca.ss
}

func (ca *coreApi) Helper() helper.Helper {
	return ca.h
}
