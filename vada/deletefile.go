package vada

import (
	"net/url"
)

func deleteFile(host string, objectKey string, bucketKey string, accessToken string) error {
	url, err := url.Parse(host + "/oss/v2/buckets/" + bucketKey + "/objects/")
	if err != nil {
		return err
	}

	url.Path += objectKey

	req, err := newRequest("DELETE", url.String(), nil, accessToken, "")
	if err != nil {
		return err
	}

	_, err = doAdhocJsonRequest(req)
	return err
}
