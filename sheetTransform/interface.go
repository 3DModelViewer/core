package sheettransform

type get func(forUser string, ids []string) ([]*SheetTransform, error)
type getForProjectSpaceVersion func(forUser string, projectSpaceVersion string) ([]*SheetTransform, error)

type SheetTransformStore interface {
	Get(forUser string, ids []string) ([]*SheetTransform, error)
	GetForProjectSpaceVersion(forUser string, projectSpaceVersion string) ([]*SheetTransform, error)
}
