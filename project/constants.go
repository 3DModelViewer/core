package project

import(
	"strings"
)

const (
	NameAsc     = sortBy("nameAsc")
	NameDesc    = sortBy("nameDesc")
	CreatedAsc  = sortBy("createdAsc")
	CreatedDesc = sortBy("createdDesc")

	Any         = Role("any") //used for filtering only
	Owner       = Role("owner")
	Admin       = Role("admin")
	Organiser   = Role("organiser")
	Contributor = Role("contributor")
	Observer    = Role("observer")
)

type sortBy string
type Role string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "createddesc":
		return CreatedDesc
	case "createdasc":
		return CreatedAsc
	case "namedesc":
		return NameDesc
	default:
		return NameAsc
	}
}
