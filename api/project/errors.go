package project

import(
	"fmt"
)

type cantFindValidImageFileExtensionError struct{
	imageName string
}

func (e *cantFindValidImageFileExtensionError) Error() string {
	return fmt.Sprintf("can't find image file extension in file name: %q", e.imageName)
}