package sheettransform

import(
	"database/sql"
)

type saveSheetTransformsForProjectSpace func(forUser string, sheetTransforms []*SheetTransform) ([]*SheetTransform, error)
type get func(forUser string, ids []string) ([]*SheetTransform, error)
type getForProjectSpaceVersion func(forUser string, projectSpaceVersion string, offset int, limit int, sortBy sortBy) ([]*SheetTransform, error)

type SheetTransformStore interface {
	Get(forUser string, ids []string) ([]*SheetTransform, error)
	GetForProjectSpaceVersion(forUser string, projectSpaceVersion string, offset int, limit int, sortBy sortBy) ([]*SheetTransform, error)
}
