package project

import (
	"strings"
)

const (
	NameAsc      = sortBy("nameAsc")
	NameDesc     = sortBy("nameDesc")
	FullNameAsc  = sortBy("fullNameAsc")
	FullNameDesc = sortBy("fullNameDesc")
	RoleAsc      = sortBy("roleAsc")
	RoleDesc     = sortBy("roleDesc")
	CreatedAsc   = sortBy("createdAsc")
	CreatedDesc  = sortBy("createdDesc")

	Any         = role("any") //used for filtering only
	Owner       = role("owner")
	Admin       = role("admin")
	Organiser   = role("organiser")
	Contributor = role("contributor")
	Observer    = role("observer")
)

type sortBy string
type role string

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

func Role(r string) role {
	switch strings.ToLower(r) {
	case "owner":
		return Owner
	case "admin":
		return Admin
	case "organiser":
		return Organiser
	case "contributor":
		return Contributor
	case "observer":
		return Observer
	default:
		return Any
	}
}
