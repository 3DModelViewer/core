package sheet

type Sheet_ struct {
	Sheet
	BaseUrn         string       `json:"baseUrn"`
}

type Sheet struct {
	Id              string       `json:"id"`
	DocumentVersion string       `json:"documentVersion"`
	Project         string       `json:"project"`
	Name            string       `json:"name"`
	Thumbnails      []string 	 `json:"thumbnails"`
	Path            string       `json:"path"`
	Role            string       `json:"role"`
}
