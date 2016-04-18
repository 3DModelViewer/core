package sheettransform

import (
	"encoding/json"
	sj "github.com/robsix/json"
	"strings"
)

func getSheetTransformHashJson(st *SheetTransform) (string, error) {
	obj := &sheetTransformHashObj{
		Id:        st.Sheet,
		Transform: &st.Transform,
	}
	if data, err := json.Marshal(obj); err != nil {
		return "", err
	} else {
		if js, err := sj.FromBytes(data); err != nil {
			return "", err
		} else {
			if isDefaultTransform(obj.Transform) {
				js.Del("transform")
			} else {
				if isDefaultScale(&obj.Transform.Scale) {
					js.Del("transform", "scale")
				} else {
					if obj.Transform.Scale.X == 1 {
						js.Del("transform", "scale", "x")
					}
					if obj.Transform.Scale.Y == 1 {
						js.Del("transform", "scale", "y")
					}
					if obj.Transform.Scale.Z == 1 {
						js.Del("transform", "scale", "z")
					}
				}
				if isDefaultRotate(&obj.Transform.Rotate) {
					js.Del("transform", "rotate")
				} else {
					if obj.Transform.Rotate.W == 1 {
						js.Del("transform", "rotate", "w")
					}
					if obj.Transform.Rotate.X == 0 {
						js.Del("transform", "rotate", "x")
					}
					if obj.Transform.Rotate.Y == 0 {
						js.Del("transform", "rotate", "y")
					}
					if obj.Transform.Rotate.Z == 0 {
						js.Del("transform", "rotate", "z")
					}
				}
				if isDefaultTranslate(&obj.Transform.Translate) {
					js.Del("transform", "translate")
				} else {
					if obj.Transform.Translate.X == 0 {
						js.Del("transform", "translate", "x")
					}
					if obj.Transform.Translate.Y == 0 {
						js.Del("transform", "translate", "y")
					}
					if obj.Transform.Translate.Z == 0 {
						js.Del("transform", "translate", "z")
					}
				}
			}
			str, err := js.ToString()
			return strings.Replace(str, " ", "", -1), err
		}
	}
}

func getTransformFromHashJson(hashJson string) (*sheetTransformHashObj, error) {
	dst := &sheetTransformHashObj{
		Transform: &Transform{
			Scale: Vector3{
				X: 1,
				Y: 1,
				Z: 1,
			},
			Rotate: Quaternion{
				W: 1,
			},
		},
	}
	err := json.Unmarshal([]byte(hashJson), dst)
	return dst, err
}

type sheetTransformHashObj struct {
	Id        string     `json:"id"`
	Transform *Transform `json:"transform"`
}

func isDefaultTransform(t *Transform) bool {
	return isDefaultScale(&t.Scale) && isDefaultRotate(&t.Rotate) && isDefaultTranslate(&t.Translate)
}

func isDefaultScale(v *Vector3) bool {
	return v.X == 1 && v.Y == 1 && v.Z == 1
}

func isDefaultRotate(q *Quaternion) bool {
	return q.W == 1 && q.X == 0 && q.Y == 0 && q.Z == 0
}

func isDefaultTranslate(v *Vector3) bool {
	return v.X == 0 && v.Y == 0 && v.Z == 0
}
