package sheettransform

type SheetTransform struct {
	Id               string    `json:"id"`
	Sheet            string    `json:"sheet"`
	Transform        Transform `json:"transform"`
	ClashChangeRegId string    `json:"clashChangeRegId"`
	DocumentVersion  string    `json:"documentVersion"`
	Project          string    `json:"project"`
	Name             string    `json:"name"`
	Thumbnails       []string  `json:"thumbnails"`
	BaseUrn          string    `json:"-"`
	Manifest         string    `json:"manifest"`
	Role             string    `json:"role"`
}

type Transform struct {
	Scale     Vector3    `json:"scale"`
	Rotate    Quaternion `json:"rotate"`
	Translate Vector3    `json:"translate"`
}

type Vector3 struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
	Z float64 `json:"z"`
}

type Quaternion struct {
	W float64 `json:"w"`
	Vector3
}
