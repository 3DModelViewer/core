package clashtest

import (
	"github.com/modelhub/caca"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"errors"
)

func newClashTestStore(getForSheetTransforms getForSheetTransforms, caca caca.CacaClient, log golog.Log) ClashTestStore {
	return &clashTestStore{
		getForSheetTransforms: getForSheetTransforms,
		caca: caca,
		log:  log,
	}
}

type clashTestStore struct {
	getForSheetTransforms getForSheetTransforms
	caca                  caca.CacaClient
	log                   golog.Log
}

func (cts *clashTestStore) GetForSheetTransforms(forUser string, leftSheetTransform string, rightSheetTransform string) (*json.Json, error) {
	if clashTestId, err := cts.getForSheetTransforms(forUser, leftSheetTransform, rightSheetTransform); err != nil {
		cts.log.Error("ClashTestStore.GetForSheetTransforms error: forUser: %q leftSheetTransform: %q rightSheetTransform: %q error: %v", forUser, leftSheetTransform, rightSheetTransform, err)
		return nil, err
	} else if clashTestId != "" {
		if js, err := cts.caca.GetClashTest(clashTestId); err != nil {
			cts.log.Error("ClashTestStore.GetForSheetTransforms error: forUser: %q leftSheetTransform: %q rightSheetTransform: %q error: %v", forUser, leftSheetTransform, rightSheetTransform, err)
			return nil, err
		} else {
			js.Del("data", "left", "urn")
			js.Del("data", "right", "urn")
			cts.log.Info("ClashTestStore.GetForSheetTransforms success: forUser: %q leftSheetTransform: %q rightSheetTransform: %q", forUser, leftSheetTransform, rightSheetTransform)
			return js, nil
		}
	} else {
		err = errors.New("No clash test exists for given sheetTransforms")
		cts.log.Error("ClashTestStore.GetForSheetTransforms error: forUser: %q leftSheetTransform: %q rightSheetTransform: %q error: %v", forUser, leftSheetTransform, rightSheetTransform, err)
		return nil, err
	}
}
