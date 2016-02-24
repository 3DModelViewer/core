package vada

func deleteBucket(host string, bucketKey string, accessToken string) error {
	req, err := newRequest("DELETE", host+"/oss/v2/buckets/"+bucketKey, nil, accessToken, "")
	if err != nil {
		return err
	}

	_, err = doAdhocJsonRequest(req)
	return err
}
