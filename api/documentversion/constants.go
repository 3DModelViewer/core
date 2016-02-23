package documentversion

const (
	VersionAsc                  = sortBy("versionAsc")
	VersionDec                  = sortBy("versionDec")
	documentVersionJsonProperty = "_modelhub_document_version_"
	projectJsonProperty         = "_modelhub_project_"
)

type sortBy string
