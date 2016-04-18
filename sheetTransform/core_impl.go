package sheettransform

import (
	"github.com/robsix/golog"
)

func newSheetTransformStore(get get, getForProjectSpaceVersion getForProjectSpaceVersion, log golog.Log) SheetTransformStore {
	return &sheetTransformStore{
		get: get,
		getForProjectSpaceVersion: getForProjectSpaceVersion,
		log: log,
	}
}

type sheetTransformStore struct {
	get                       get
	getForProjectSpaceVersion getForProjectSpaceVersion
	log                       golog.Log
}

func (sts *sheetTransformStore) Get(forUser string, ids []string) ([]*SheetTransform, error) {
	if sheetTransforms, err := sts.get(forUser, ids); err != nil {
		sts.log.Error("SheetTransformStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		sts.log.Info("SheetTransformStore.Get success: forUser: %q ids: %v", forUser, ids)
		return sheetTransforms, nil
	}
}

func (sts *sheetTransformStore) GetForProjectSpaceVersion(forUser string, projectSpaceVersion string, offset int, limit int, sortBy sortBy) ([]*SheetTransform, int, error) {
	if sheetTransforms, totalResults, err := sts.getForProjectSpaceVersion(forUser, projectSpaceVersion, offset, limit, sortBy); err != nil {
		sts.log.Error("SheetTransformStore.GetForProjectSpaceVersion error: forUser: %q projectSpaceVersion: %q offset: %d limit: %d sortBy: %q error: %v", forUser, projectSpaceVersion, offset, limit, sortBy, err)
		return sheetTransforms, totalResults, err
	} else {
		sts.log.Info("SheetTransformStore.GetForProjectSpaceVersion success: forUser: %q projectSpaceVersion: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, projectSpaceVersion, offset, limit, sortBy, totalResults)
		return sheetTransforms, totalResults, nil
	}
}
