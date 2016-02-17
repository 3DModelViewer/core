package user

const (
	FullNameAsc = sortBy("fullNameAsc")
	FullNameDec = sortBy("fullNameDesc")
)

type sortBy string
