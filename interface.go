package core

import (
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/helper"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/projectspaceversion"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/sheettransform"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/user"
	"github.com/modelhub/core/clashtest"
)

type CoreApi interface {
	User() user.UserStore
	Project() project.ProjectStore
	TreeNode() treenode.TreeNodeStore
	DocumentVersion() documentversion.DocumentVersionStore
	ProjectSpaceVersion() projectspaceversion.ProjectSpaceVersionStore
	Sheet() sheet.SheetStore
	SheetTransform() sheettransform.SheetTransformStore
	ClashTest() clashtest.ClashTestStore
	Helper() helper.Helper
}
