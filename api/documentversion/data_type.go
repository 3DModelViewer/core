package documentversion

import (
	"time"
)

type _documentVersion struct {
	DocumentVersion
	Urn string `json:"urn"`
}

type DocumentVersion struct {
	Id            string    `json:"id"`
	Document      string    `json:"document"`
	Version       int       `json:"version"`
	Project       string    `json:"project"`
	Uploaded      time.Time `json:"uploaded"`
	UploadComment string    `json:"uploadComment"`
	UploadedBy    string    `json:"uploadedBy"`
	FileExtension string    `json:"fileExtension"`
	Status        string    `json:"status"`
}
