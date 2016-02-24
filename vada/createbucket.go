package vada

import (
	"errors"
	. "github.com/robsix/json"
	"regexp"
)

func createBucket(host string, bucketKey string, policyKey BucketPolicy, accessToken string) (ret *Json, err error) {
	re := regexp.MustCompile(bucketValidationRegexp)
	if !re.MatchString(bucketKey) {
		return nil, errors.New("invalid bucket name: " + bucketKey + " must match regexp: " + bucketValidationRegexp)
	}

	data, err := FromString(`{"bucketKey":"` + bucketKey + `","policyKey":"` + string(policyKey) + `"}`)
	if err != nil {
		return nil, err
	}

	reader, err := data.ToReader()
	if err != nil {
		return nil, err
	}

	req, err := newRequest("POST", host+"/oss/v2/buckets", reader, accessToken, "application/json")
	if err != nil {
		return nil, err
	}

	ret, err = doAdhocJsonRequest(req)
	return
}
