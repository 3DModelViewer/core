package sheet

type Sheet_ struct {
	Sheet
	BaseUrn string `json:"baseUrn"`
}

type Sheet struct {
	Id              string   `json:"id"`
	DocumentVersion string   `json:"documentVersion"`
	Project         string   `json:"project"`
	Name            string   `json:"name"`
	Thumbnails      []string `json:"thumbnails"`
	Manifest        string   `json:"manifest"`
	Role            string   `json:"role"`
}
