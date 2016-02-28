package user

const (
	FullNameAsc  = sortBy("fullNameAsc")
	FullNameDesc = sortBy("fullNameDesc")

	Description = property("description")
	UILanguage  = property("uilanguage")
	UITheme     = property("uitheme")
	Locale      = property("locale")
	TimeFormat  = property("timeformat")
)

type sortBy string
type property string
