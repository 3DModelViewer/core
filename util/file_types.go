package util

import (
	"errors"
	"strings"
)

var fileTypes = map[string]string{
	//open document format
	"odt": "od",
	"ods": "od",
	"odp": "od",
	"odg": "od",
	"odf": "od",
	"fodt": "od",
	"fods": "od",
	"fodp": "od",
	"fodg": "od",
	"fodf": "od",
	//pdf
	"pdf": "pdf",
	//text
	"csv": "text",
	"txt": "text",
	"md": "text",
	//image
	"png":  "image",
	"jpeg": "image",
	"jpg":  "image",
	"gif":  "image",
	"webp": "image",
	//video
	"mp4":  "video",
	"ogg":  "video",
	"ogv":  "video",
	"webm": "video",
	//audio
	"aac":  "audio",
	"mp3":  "audio",
	"mp1":  "audio",
	"mp2":  "audio",
	"mpg":  "audio",
	"mpeg": "audio",
	"oga":  "audio",
	"wav":  "audio",
	//lmv
	"3dm":           "lmv",
	"3ds":           "lmv",
	"asm":           "lmv",
	"cam360":        "lmv",
	"catpart":       "lmv",
	"catproduct":    "lmv",
	"cgr":           "lmv",
	"collaboration": "lmv",
	"dlv3":          "lmv",
	"dwf":           "lmv",
	"dwfx":          "lmv",
	"dwg":           "lmv",
	"dwt":           "lmv",
	"dxf":           "lmv",
	"exp":           "lmv",
	"f3d":           "lmv",
	"fbx":           "lmv",
	"g":             "lmv",
	"iam":           "lmv",
	"idw":           "lmv",
	"ifc":           "lmv",
	"ige":           "lmv",
	"iges":          "lmv",
	"igs":           "lmv",
	"ipt":           "lmv",
	"jt":            "lmv",
	"model":         "lmv",
	"neu":           "lmv",
	"nwc":           "lmv",
	"nwd":           "lmv",
	"prt":           "lmv",
	"rcp":           "lmv",
	"rvt":           "lmv",
	"sab":           "lmv",
	"sat":           "lmv",
	"session":       "lmv",
	"sim":           "lmv",
	"sim360":        "lmv",
	"skp":           "lmv",
	"sldasm":        "lmv",
	"sldprt":        "lmv",
	"smb":           "lmv",
	"smt":           "lmv",
	"ste":           "lmv",
	"step":          "lmv",
	"stl":           "lmv",
	"stla":          "lmv",
	"stlb":          "lmv",
	"stp":           "lmv",
	"wire":          "lmv",
	"x_b":           "lmv",
	"x_t":           "lmv",
	"xas":           "lmv",
	"xpr":           "lmv",
}

func getFileType(fileExtension string) (string, error) {
	if fileType, exists := fileTypes[strings.ToLower(fileExtension)]; exists {
		return fileType, nil
	} else {
		return "", errors.New("unkonwn file type")
	}
}
