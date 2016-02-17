package util

import (
	"github.com/twinj/uuid"
	"strings"
)

func NewId() string {
	return strings.Replace(uuid.NewV4().String(), "-", "", -1)
}
