package sheet

import (
	"net/http"
)

type setName func(forUser string, id string, newName string) error
type get func(forUser string, ids []string) ([]*Sheet_, error)
type getForDocumentVersion func(forUser string, documentVersion string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error)
type globalSearch func(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error)
type projectSearch func(forUser string, project string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet_, int, error)

type SheetStore interface {
	SetName(forUser string, id string, newName string) error
	GetItem(forUser string, id string, path string) (*http.Response, string, error)
	Get(forUser string, ids []string) ([]*Sheet, error)
	GetForDocumentVersion(forUser string, documentVersion string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error)
	GlobalSearch(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error)
	ProjectSearch(forUser string, project string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error)
}
