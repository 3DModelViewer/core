package util

import (
	"github.com/twinj/uuid"
	"strings"
)

func NewId() string {
	return strings.Replace(uuid.NewV4().String(), "-", "", -1)
}

func IdToUuidFormat(id string) string {
	return id[:8]+ "-" + id[8:12] + "-" + id[12:16] + "-" + id[16:20] + "-" + id[20:]
}
