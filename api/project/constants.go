package project

const (
	NameAsc    = sortBy("nameAsc")
	NameDec    = sortBy("nameDec")
	CreatedAsc = sortBy("createdAsc")
	CreatedDec = sortBy("createdDec")

	Owner       = Role("owner")
	Admin       = Role("admin")
	Organiser   = Role("organiser")
	Contributor = Role("contributor")
	Observer    = Role("observer")
)

type sortBy string
type Role string
