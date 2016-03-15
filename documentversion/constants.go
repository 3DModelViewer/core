package documentversion

import (
	"strings"
)

const (
	VersionAsc                  = sortBy("versionAsc")
	VersionDesc                 = sortBy("versionDesc")
	documentVersionJsonProperty = "_modelhub_document_version_"
	projectJsonProperty         = "_modelhub_project_"
)

type sortBy string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "versiondesc":
		return VersionDesc
	default:
		return VersionAsc
	}
}
