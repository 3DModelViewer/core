package projectspaceversion

import (
	"github.com/modelhub/core/sheettransform"
	"github.com/robsix/json"
	"io"
	"net/http"
)

type create func(forUser string, projectSpace string, projectSpaceVersionId string, createComment string, sheetTransforms []string, camera *json.Json, thumbnailType string) (*ProjectSpaceVersion, error)
type get func(forUser string, ids []string) ([]*ProjectSpaceVersion, error)
type getForProjectSpace func(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceVersion, int, error)

type ProjectSpaceVersionStore interface {
	Create(forUser string, projectSpace string, createComment string, sheetTransforms []*sheettransform.SheetTransform, camera *json.Json, thumbnailType string, thumbnail io.ReadCloser) (*ProjectSpaceVersion, error)
	Get(forUser string, ids []string) ([]*ProjectSpaceVersion, error)
	GetForProjectSpace(forUser string, projectSpace string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceVersion, int, error)
	GetThumbnail(forUser string, id string) (*http.Response, error)
}
