package vada

import (
	sj "github.com/robsix/json"
	"io"
	"net/url"
)

func uploadFile(host string, objectKey string, bucketKey string, file io.ReadCloser, accessToken string) (ret *sj.Json, err error) {
	defer file.Close()
	url, err := url.Parse(host + "/oss/v2/buckets/" + bucketKey + "/objects/")
	if err != nil {
		return nil, err
	}

	url.Path += objectKey

	req, err := newRequest("PUT", url.String(), file, accessToken, "application/octet-stream")
	if err != nil {
		return nil, err
	}

	ret, err = doAdhocJsonRequest(req)
	return
}
