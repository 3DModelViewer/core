package project

import (
	"time"
)

type Project struct {
	Id            string    `json:"id"`
	Name          string    `json:"name"`
	Created       time.Time `json:"created"`
	ThumbnailType string    `json:"thumbnailType"`
}

type ProjectInUserContext struct {
	Project
	Role string `json:"role"`
}

type Membership struct {
	User string `json:"user"`
	Role string `json:"role"`
}
