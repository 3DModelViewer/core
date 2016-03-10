package project

import (
	"time"
)

type Project struct {
	Id                 string    `json:"id"`
	Name               string    `json:"name"`
	Created            time.Time `json:"created"`
	ImageFileExtension string    `json:"imageFileExtension"`
}

type ProjectInUserContext struct {
	Project
	Role string `json:"role"`
}

type Membership struct {
	User string `json:"user"`
	Role string `json:"role"`
}
