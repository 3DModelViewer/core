package user

type CurrentUser struct {
	User
	SuperUser  bool   `json:"superUser"`
	UILanguage string `json:"uiLanguage"`
	UITheme    string `json:"uiTheme"`
	TimeFormat string `json:"timeFormat"`
}

type User struct {
	Id       string `json:"id"`
	Avatar   string `json:"avatar"`
	FullName string `json:"fullName"`
}
