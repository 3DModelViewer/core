package user

const (
	FullNameAsc  = sortBy("fullNameAsc")
	FullNameDesc = sortBy("fullNameDesc")
)

type sortBy string
