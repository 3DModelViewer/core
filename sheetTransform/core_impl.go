package sheettransform

import (
	"github.com/robsix/golog"
)

func newSheetTransformStore(bulkSave bulkSave, bulkSetClashChangeRegId bulkSetClashChangeRegId, get get, getForHashes getForHashes, getForProjectSpaceVersion getForProjectSpaceVersion, log golog.Log) SheetTransformStore {
	return &sheetTransformStore{
		bulkSave: bulkSave,
		bulkSetClashChangeRegId: bulkSetClashChangeRegId,
		get: get,
		getForHashes: getForHashes,
		getForProjectSpaceVersion: getForProjectSpaceVersion,
		log: log,
	}
}

type sheetTransformStore struct {
	bulkSave bulkSave
	bulkSetClashChangeRegId bulkSetClashChangeRegId
	get                       get
	getForHashes getForHashes
	getForProjectSpaceVersion getForProjectSpaceVersion
	log                       golog.Log
}

func (sts *sheetTransformStore) BulkSave(forUser string, ids []string) ([]*SheetTransform, error) {
	if sheetTransforms, err := sts.get(forUser, ids); err != nil {
		sts.log.Error("SheetTransformStore.BulkSave error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		sts.log.Info("SheetTransformStore.BulkSave success: forUser: %q ids: %v", forUser, ids)
		return sheetTransforms, nil
	}
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

func (sts *sheetTransformStore) GetForProjectSpaceVersion(forUser string, projectSpaceVersion string) ([]*SheetTransform, error) {
	if sheetTransforms, err := sts.getForProjectSpaceVersion(forUser, projectSpaceVersion); err != nil {
		sts.log.Error("SheetTransformStore.GetForProjectSpaceVersion error: forUser: %q projectSpaceVersion: %q error: %v", forUser, projectSpaceVersion, err)
		return sheetTransforms, err
	} else {
		sts.log.Info("SheetTransformStore.GetForProjectSpaceVersion success: forUser: %q projectSpaceVersion: %q", forUser, projectSpaceVersion)
		return sheetTransforms, nil
	}
}
