package clashtest

import "github.com/robsix/json"

type getForSheetTransforms func(forUser string, leftSheetTransform string, rightSheetTransform string) (string, bool, error)

type ClashTestStore interface {
	GetForSheetTransforms(forUser string, leftSheetTransform string, rightSheetTransform string) (*json.Json, bool, error)
}
