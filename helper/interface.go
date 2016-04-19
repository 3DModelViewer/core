package helper

type Helper interface {
	GetChildrenDocumentsWithLatestVersionAndFirstSheetInfo(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*DocumentNode, int, error)
	GetDocumentVersionsWithFirstSheetInfo(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error)
	GetChildrenProjectSpacesWithLatestVersion(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceNode, int, error)
}
