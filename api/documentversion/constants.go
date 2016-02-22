package documentversion

const (
	VersionAsc = sortBy("versionAsc")
	VersionDec = sortBy("versionDec")
)

type sortBy string
