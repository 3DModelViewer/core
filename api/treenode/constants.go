package treenode

const (
	NameAsc  = sortBy("nameAsc")
	NameDesc = sortBy("nameDesc")

	Any         = nodeType("any") //used for results filtering only
	Folder      = nodeType("folder")
	Document    = nodeType("document")
	ViewerState = nodeType("viewerState")
)

type sortBy string
type nodeType string
