package sheet

import (
	"strings"
)

const (
	NameAsc  = sortBy("nameAsc")
	NameDesc = sortBy("nameDesc")
)

type sortBy string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "namedesc":
		return NameDesc
	default:
		return NameAsc
	}
}
