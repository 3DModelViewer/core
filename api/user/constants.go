package user

const (
	FullNameAsc = sortBy("fullNameAsc")
	FullNameDec = sortBy("fullNameDec")
)

type sortBy string
