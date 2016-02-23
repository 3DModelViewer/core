package vada

import (
	"net/http"
)

func getSeedFile(host string, objectKey string, bucketKey string, accessToken string) (ret *http.Response, err error) {
	req, err := newRequest("GET", host + "/oss/v2/buckets/"+bucketKey+"/objects/"+objectKey, nil, accessToken, "")
	if err != nil {
		return nil, err
	}

	client := http.DefaultClient
	ret, err = client.Do(req)
	if ret != nil {
		err = checkResponse(ret, err)
	}
	return
}
