package documentversion

const (
	VersionAsc                  = sortBy("versionAsc")
	VersionDesc                 = sortBy("versionDesc")
	documentVersionJsonProperty = "_modelhub_document_version_"
	projectJsonProperty         = "_modelhub_project_"
)

type sortBy string
