package project

import (
	"time"
)

type Project struct {
	Id                 string    `json:"id"`
	Name               string    `json:"name"`
	Description        string    `json:"description"`
	Created            time.Time `json:"created"`
	ImageFileExtension string    `json:"imageFileExtension"`
}

type ProjectInUserContext struct {
	Project
	Role string `json:"role"`
}
