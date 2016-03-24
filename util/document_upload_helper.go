package util

import (
	"encoding/base64"
	"errors"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"io"
	"path/filepath"
	"strings"
)

func DocumentUploadHelper(fileName string, fileType string, file io.ReadCloser, thumbnailType string, thumbnail io.ReadCloser, ossBucket string, vada vada.VadaClient, log golog.Log) (newDocVerId string, status string, urn string, fExt string, fType string, tnType string, err error) {
	if file == nil {
		err := errors.New("file required")
		log.Error("DocumentUploadHelper error: %v", err)
		return "", "", "", "", fileType, "", err
	}
	defer file.Close()
	if thumbnail != nil {
		defer thumbnail.Close()
	}

	fileExtension := filepath.Ext(fileName)
	if len(fileExtension) >= 1 {
		fileExtension = fileExtension[1:] //cut of the .
	}
	fExt = fileExtension
	tnType = thumbnailType

	fType, _ = getFileType(fileExtension)
	if fType == "image" || fType == "video" || fType == "audio" || fType == "" {
		fType = fileType
	}
	newDocVerId = NewId()

	log.Info("DocumentUploadHelper starting upload of file: %q to bucket: %q", newDocVerId+"."+fileExtension, ossBucket)
	uploadResp, err := vada.UploadFile(newDocVerId+"."+fileExtension, ossBucket, file)
	if err != nil {
		return "", "", "", fExt, fType, "", err
	}

	if thumbnail != nil && strings.HasPrefix(thumbnailType, "image/") {
		if _, err = vada.UploadFile(newDocVerId+".tn.tn", ossBucket, thumbnail); err != nil {
			tnType = ""
		}
	} else {
		tnType = ""
	}

	urn, err = uploadResp.String("objectId")
	if err != nil {
		return newDocVerId, "", urn, fExt, fType, tnType, err
	}

	if fType == "lmv" {
		log.Info("DocumentUploadHelper registering file: %q", newDocVerId+"."+fileExtension)
		b64Urn := ToBase64(urn)
		_, err = vada.RegisterFile(b64Urn)
		if err != nil {
			status = "failed_to_register"
		} else {
			status = "registered"
		}
	} else {
		status = "wont_register"
	}

	return newDocVerId, status, urn, fExt, fType, tnType, err
}

func ToBase64(str string) string {
	return base64.StdEncoding.EncodeToString([]byte(str))
}
