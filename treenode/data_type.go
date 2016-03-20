package treenode
import "time"

type TreeNode struct {
	Id       string   `json:"id"`
	Parent   string   `json:"parent"`
	Project  string   `json:"project"`
	NodeType nodeType `json:"nodeType"`
	Name     string   `json:"name"`
}

type DocumentNode struct {
	TreeNode
	LatestVersion latestVersion
}

type latestVersion struct{
	Id            string    `json:"id"`
	Version       int       `json:"version"`
	Uploaded      time.Time `json:"uploaded"`
	FileType      string    `json:"fileType"`
	FileExtension string    `json:"fileExtension"`
	Status        string    `json:"status"`
	ThumbnailType string    `json:"thumbnailType"`
}