package projectspaceversion

import (
	"strings"
)

const (
	VersionAsc  = sortBy("versionAsc")
	VersionDesc = sortBy("versionDesc")
)

type sortBy string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "versiondesc":
		return VersionDesc
	default:
		return VersionAsc
	}
}
