package user

import (
	"errors"
	"strings"
)

const (
	FullNameAsc  = sortBy("fullNameAsc")
	FullNameDesc = sortBy("fullNameDesc")

	Description = property("description")
	UILanguage  = property("uilanguage")
	UITheme     = property("uitheme")
	TimeFormat  = property("timeformat")
)

type sortBy string
type property string

func SortBy(sb string) sortBy {
	switch strings.ToLower(sb) {
	case "fullnamedesc":
		return FullNameDesc
	default:
		return FullNameAsc
	}
}

func Property(p string) (property, error) {
	switch strings.ToLower(p) {
	case "description":
		return Description, nil
	case "uilanguage":
		return UILanguage, nil
	case "uitheme":
		return UITheme, nil
	case "timeformat":
		return TimeFormat, nil
	default:
		return property(""), errors.New("Unknown property")
	}
}
