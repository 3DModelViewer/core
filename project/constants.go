package project

const (
	NameAsc     = sortBy("nameAsc")
	NameDesc    = sortBy("nameDesc")
	CreatedAsc  = sortBy("createdAsc")
	CreatedDesc = sortBy("createdDesc")

	Owner       = Role("owner")
	Admin       = Role("admin")
	Organiser   = Role("organiser")
	Contributor = Role("contributor")
	Observer    = Role("observer")
)

type sortBy string
type Role string
