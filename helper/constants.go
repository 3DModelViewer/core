package helper

import (
	"strings"
)

const (
	NameAsc  = sortBy("nameAsc")
	NameDesc = sortBy("nameDesc")
	VersionAsc = sortBy("versionAsc")
	VersionDesc = sortBy("versionDesc")
)

type sortBy string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "versiondesc":
		return VersionDesc
	case "versionasc":
		return VersionAsc
	case "namedesc":
		return NameDesc
	default:
		return NameAsc
	}
}