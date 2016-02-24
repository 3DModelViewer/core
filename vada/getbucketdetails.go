package vada

import (
	sj "github.com/robsix/json"
)

func getBucketDetails(host string, bucketKey string, accessToken string) (ret *sj.Json, err error) {
	req, err := newRequest("GET", host+"/oss/v2/buckets/"+bucketKey+"/details", nil, accessToken, "")
	if err != nil {
		return nil, err
	}

	ret, err = doAdhocJsonRequest(req)
	return
}
