package treenode

type TreeNode struct {
	Id       string   `json:"id"`
	Parent   string   `json:"parent"`
	Project  string   `json:"project"`
	NodeType nodeType `json:"nodeType"`
	Name     string   `json:"name"`
	ChildCount int `json:"childCount"`
}
