package helper

import (
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/treenode"
)

type DocumentNode struct {
	*treenode.TreeNode
	LatestVersion *latestVersion `json:"latestVersion,omitempty"`
}

type latestVersion struct {
	Id            string      `json:"id"`
	FileType      string      `json:"fileType"`
	FileExtension string      `json:"fileExtension"`
	Status        string      `json:"status"`
	ThumbnailType string      `json:"thumbnailType"`
	SheetCount    int         `json:"sheetCount"`
	FirstSheet    *firstSheet `json:"firstSheet,omitempty"`
}

type firstSheet struct {
	Id         string   `json:"id"`
	Thumbnails []string `json:"thumbnails"`
	Manifest   string   `json:"manifest"`
	Role       string   `json:"role"`
}

type DocumentVersion struct {
	*documentversion.DocumentVersion
	FirstSheet *firstSheet `json:"firstSheet,omitempty"`
}
