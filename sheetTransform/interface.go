package sheettransform

type bulkSave func(forUser string, sheetTransforms []*SheetTransform)
type bulkSetClashChangeRegId func(sheetTransforms []*SheetTransform) error
type get func(forUser string, ids []string) ([]*SheetTransform, error)
type getForHashes func(sheetTransforms []*SheetTransform) ([]*SheetTransform, error)
type getForProjectSpaceVersion func(forUser string, projectSpaceVersion string) ([]*SheetTransform, error)

type SheetTransformStore interface {
	BulkSave(forUser string, sheetTransforms []*SheetTransform) ([]*SheetTransform, error)
	BulkSetClashChangeRegId(sheetTransforms []*SheetTransform) error
	Get(forUser string, ids []string) ([]*SheetTransform, error)
	GetForHashes(sheetTransforms []*SheetTransform) ([]*SheetTransform, error)
	GetForProjectSpaceVersion(forUser string, projectSpaceVersion string) ([]*SheetTransform, error)
}
