package core

import (
	"github.com/modelhub/core/user"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/sheet"
	"errors"
)

func newCoreApi(us user.UserStore, ps project.ProjectStore, tns treenode.TreeNodeStore, dvs documentversion.DocumentVersionStore, ss sheet.SheetStore) (CoreApi, error) {
	if us == nil || ps == nil || tns == nil || dvs == nil || ss == nil {
		return nil, errors.New("nil values to CoreApi parameters or not allowed")
	}
	return &coreApi{
		us: us,
		ps: ps,
		tns: tns,
		dvs: dvs,
		ss: ss,
	}, nil
}

type coreApi struct {
	us user.UserStore
	ps project.ProjectStore
	tns treenode.TreeNodeStore
	dvs documentversion.DocumentVersionStore
	ss sheet.SheetStore
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