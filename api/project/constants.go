package project

const (
	NameAsc    = sortBy("nameAsc")
	NameDec    = sortBy("nameDesc")
	CreatedAsc = sortBy("createdAsc")
	CreatedDec = sortBy("createdDesc")

	Owner       = Role("owner")
	Admin       = Role("admin")
	Organiser   = Role("organiser")
	Contributor = Role("contributor")
	Observer    = Role("observer")
)

type sortBy string
type Role string
