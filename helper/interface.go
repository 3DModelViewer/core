package helper

type Helper interface {
	GetChildrenDocumentsWithLatestVersionAndFirstSheetInfo(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*DocumentNode, int, error)
}
