package user

type CurrentUser struct {
	UserWithDescription
	SuperUser  bool   `json:"superUser"`
	UILanguage string `json:"uiLanguage"`
	UITheme    string `json:"uiTheme"`
	Locale   string `json:"locale"`
	TimeFormat string `json:"timeFormat"`
}

type User struct {
	Id          string `json:"id"`
	Avatar      string `json:"avatar"`
	FullName    string `json:"fullName"`
}

type UserWithDescription struct{
	User
	Description string `json:"description"`
}

type UserInProjectContext struct {
	User
	Role string `json:"role"`
}
