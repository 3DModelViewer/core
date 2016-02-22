package util

import (
	"encoding/base64"
	"errors"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"path/filepath"
	"io"
)

func DocumentUploadHelper(fileName string, file io.ReadCloser, ossBucket string, vada vada.VadaClient, log golog.Log) (newDocVerId string, status string, urn string, err error) {
	if file == nil {
		err := errors.New("file required")
		log.Error("DocumentUploadHelper error: %v", err)
		return "", "", "", err
	}
	defer file.Close()

	fileExtension := filepath.Ext(fileName)
	if len(fileExtension) >= 1 {
		fileExtension = fileExtension[1:] //cut of the .
	}

	fileType, _ := getFileType(fileExtension)
	newDocVerId = NewId()

	log.Info("DocumentUploadHelper starting upload of file: %q to bucket: %q", newDocVerId+"."+fileExtension, ossBucket)
	uploadResp, err := vada.UploadFile(newDocVerId+"."+fileExtension, ossBucket, file)
	if err != nil {
		return "", "", "", err
	}

	urn, err = uploadResp.String("objectId")
	if err != nil {
		return newDocVerId, "", urn, err
	}

	if fileType == "lmv" {
		log.Info("DocumentUploadHelper registering file: %q", newDocVerId+"."+fileExtension)
		b64Urn := toBase64(urn)
		_, err = vada.RegisterFile(b64Urn)
		if err != nil {
			return newDocVerId, "failed_to_register", urn, err
		} else {
			status = "registered"
		}
	} else {
		status = "wont_register"
	}

	return newDocVerId, status, urn, err
}

func toBase64(str string) string {
	return base64.StdEncoding.EncodeToString([]byte(str))
}
