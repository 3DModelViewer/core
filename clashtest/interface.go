package clashtest

import "github.com/robsix/json"

type getForSheetTransforms func(forUser string, leftSheetTransform string, rightSheetTransform string) (string, error)

type ClashTestStore interface {
	GetForSheetTransforms(forUser string, leftSheetTransform string, rightSheetTransform string) (*json.Json, error)
}
