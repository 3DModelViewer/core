package clashtest

import (
	"github.com/modelhub/caca"
	"github.com/robsix/golog"
	"github.com/robsix/json"
	"github.com/modelhub/core/util"
	"strings"
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

func (cts *clashTestStore) GetForSheetTransforms(forUser string, leftSheetTransform string, rightSheetTransform string) (*json.Json, bool, error) {
	if clashTestId, exists, err := cts.getForSheetTransforms(forUser, leftSheetTransform, rightSheetTransform); err != nil {
		cts.log.Error("ClashTestStore.GetForSheetTransforms error: forUser: %q leftSheetTransform: %q rightSheetTransform: %q error: %v", forUser, leftSheetTransform, rightSheetTransform, err)
		return nil, exists, err
	} else if exists {
		if js, err := cts.caca.GetClashTest(util.IdToUuidFormat(clashTestId)); err != nil {
			cts.log.Error("ClashTestStore.GetForSheetTransforms error: forUser: %q leftSheetTransform: %q rightSheetTransform: %q error: %v", forUser, leftSheetTransform, rightSheetTransform, err)
			return nil, exists, err
		} else {
			js.Del("data", "left", "urn")
			js.Del("data", "right", "urn")
			js.Set(strings.Replace(js.MustString("", "data", "id"), "-", "", -1), "data", "id")
			js.Set(strings.Replace(js.MustString("", "data", "left", "id"), "-", "", -1), "data", "left", "id")
			js.Set(strings.Replace(js.MustString("", "data", "right", "id"), "-", "", -1), "data", "right", "id")
			cts.log.Info("ClashTestStore.GetForSheetTransforms success: forUser: %q leftSheetTransform: %q rightSheetTransform: %q", forUser, leftSheetTransform, rightSheetTransform)
			return js, exists, nil
		}
	} else {
		return nil, exists, err
	}
}
