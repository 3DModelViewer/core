package vada

import (
	sj "github.com/robsix/json"
)

func getSupportedFormats(host string, accessToken string) (ret *sj.Json, err error) {
	req, err := newRequest("GET", host+"/viewingservice/v1/supported", nil, accessToken, "")
	if err != nil {
		return nil, err
	}

	ret, err = doAdhocJsonRequest(req)
	return
}
