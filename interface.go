package core

import (
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/project"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/user"
	"github.com/modelhub/core/helper"
)

type CoreApi interface {
	User() user.UserStore
	Project() project.ProjectStore
	TreeNode() treenode.TreeNodeStore
	DocumentVersion() documentversion.DocumentVersionStore
	Sheet() sheet.SheetStore
	Helper() helper.Helper
}
