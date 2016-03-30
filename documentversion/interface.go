package documentversion

import (
	"github.com/modelhub/core/sheet"
	"io"
	"net/http"
)

type create func(forUser string, document string, documentVersionId string, uploadComment string, fileType string, fileExtension string, urn string, status string, thumbnailType string) (*DocumentVersion, error)
type get func(forUser string, ids []string) ([]*DocumentVersion, error)
type getForDocument func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error)
type bulkSetStatus func([]*DocumentVersion) error
type bulkSaveSheets func([]*sheet.Sheet_) error

type DocumentVersionStore interface {
	Create(forUser string, document string, uploadComment string, fileType string, fileName string, file io.ReadCloser, thumbnailType string, thumbnail io.ReadCloser) (*DocumentVersion, error)
	Get(forUser string, ids []string) ([]*DocumentVersion, error)
	GetForDocument(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error)
	GetSeedFile(forUser string, id string) (*http.Response, error)
	GetThumbnail(forUser string, id string) (*http.Response, error)
}
