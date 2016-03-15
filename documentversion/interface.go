package documentversion

import (
	"github.com/modelhub/core/sheet"
	"io"
	"net/http"
)

type create func(forUser string, document string, documentVersionId string, uploadComment string, fileExtension string, urn string, status string, thumbnailFileExtension string) (*_documentVersion, error)
type get func(forUser string, ids []string) ([]*_documentVersion, error)
type getForDocument func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*_documentVersion, int, error)
type bulkSetStatus func([]*_documentVersion) error
type bulkSaveSheets func([]*sheet.Sheet_) error

type DocumentVersionStore interface {
	Create(forUser string, document string, uploadComment string, fileName string, file io.ReadCloser, thumbnailName string, thumbnail io.ReadCloser) (*DocumentVersion, error)
	Get(forUser string, ids []string) ([]*DocumentVersion, error)
	GetForDocument(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error)
	GetSeedFile(forUser string, id string) (*http.Response, error)
}
