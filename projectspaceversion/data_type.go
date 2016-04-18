package projectspaceversion

import (
	"github.com/robsix/json"
	"time"
)

type ProjectSpaceVersion struct {
	Id                  string     `json:"id"`
	ProjectSpace        string     `json:"projectSpace"`
	Version             int        `json:"version"`
	Project             string     `json:"project"`
	Created             time.Time  `json:"created"`
	CreateComment       string     `json:"createComment"`
	CreatedBy           string     `json:"createdBy"`
	Camera              *json.Json `json:"camera"`
	ThumbnailType       string     `json:"thumbnailType"`
	SheetTransformCount int        `json:"sheetTransformCount"`
}
