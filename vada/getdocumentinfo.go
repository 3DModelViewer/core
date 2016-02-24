package vada

import (
	sj "github.com/robsix/json"
)

func getDocumentInfo(host string, b64Urn string, guid string, accessToken string) (ret *sj.Json, err error) {
	queryString := ""
	if guid != "" {
		queryString = "?guid=" + guid
	}

	req, err := newRequest("GET", host+"/viewingservice/v1/"+b64Urn+"/all"+queryString, nil, accessToken, "")
	if err != nil {
		return nil, err
	}

	ret, err = doAdhocJsonRequest(req)
	return
}
