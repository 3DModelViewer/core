package vada

import (
	sj "github.com/robsix/json"
	"encoding/base64"
	"strings"
)

func registerFile(host string, b64Urn string, accessToken string) (ret *sj.Json, err error) {
	data, err := sj.FromString(`{"urn":"`+b64Urn+`"}`)
	if err != nil {
		return nil, err
	}

	/**
	 * MAGIC super secret handling for pdf documents START
	 */

	isPdf := false
	bytes, err := base64.StdEncoding.DecodeString(b64Urn)
	if err != nil {
		return nil, err
	}

	str := string(bytes)
	if strings.HasSuffix(str, ".pdf") {
		isPdf = true
		data.Set("viewing-pdf-lmv", "channel")
	}

	/**
	 * MAGIC super secret handling for pdf documents STOP
	 */

	reader, err := data.ToReader()
	if err != nil {
		return nil, err
	}

	req, err := newRequest("POST", host + "/viewingservice/v1/register", reader, accessToken, "application/json")
	if err != nil {
		return nil, err
	}

	/**
	 * MAGIC super secret handling for pdf documents RESTART
	 */

	if isPdf {
		req.Header.Set("x-ads-force", "true")
	}

	/**
	 * MAGIC super secret handling for pdf documents RESTOP
	 */

	ret, err = doAdhocJsonRequest(req)
	return
}
