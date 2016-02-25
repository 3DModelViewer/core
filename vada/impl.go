package vada

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/robsix/golog"
	. "github.com/robsix/json"
	"io"
	"net/http"
	"sync"
	"time"
)

const (
	accessTokenExpirationBuffer = time.Duration(-10) * time.Second
)

func NewVadaClient(vadaHost string, clientKey string, clientSecret string, log golog.Log) VadaClient {
	return &vadaClient{
		host:         vadaHost,
		clientKey:    clientKey,
		clientSecret: clientSecret,
		log:          log,
	}
}

type vadaClient struct {
	host               string
	clientKey          string
	clientSecret       string
	accessToken        string
	accessTokenExpires time.Time
	log                golog.Log
	mtx                sync.Mutex
}

func (v *vadaClient) getAccessToken() (string, error) {
	if time.Now().After(v.accessTokenExpires.Add(accessTokenExpirationBuffer)) {
		defer v.mtx.Unlock()
		v.mtx.Lock()
		if time.Now().After(v.accessTokenExpires.Add(accessTokenExpirationBuffer)) {
			v.log.Info("VadaClient.getAccessToken requesting new token")
			accessToken, err := getAccessToken(v.host, v.clientKey, v.clientSecret)
			if err != nil {
				v.log.Critical("VadaClient.getAccessToken error: %v", err)
				return "", err
			}
			v.accessToken = accessToken.Token
			expiresDuration := time.Duration(accessToken.Expires) * time.Second
			v.accessTokenExpires = time.Now().Add(expiresDuration)
			v.log.Info("VadaClient.getAccessToken retrieved new access token: %q expires in: %v", v.accessToken, expiresDuration)
		}
	}
	return v.accessToken, nil
}

func (v *vadaClient) CreateBucket(bucketKey string, policyKey BucketPolicy) (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return createBucket(v.host, bucketKey, policyKey, token)
}

func (v *vadaClient) DeleteBucket(bucketKey string) error {
	token, err := v.getAccessToken()
	if err != nil {
		return err
	}

	return deleteBucket(v.host, bucketKey, token)
}

func (v *vadaClient) GetBucketDetails(bucketKey string) (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return getBucketDetails(v.host, bucketKey, token)
}

func (v *vadaClient) GetSupportedFormats() (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return getSupportedFormats(v.host, token)
}

func (v *vadaClient) UploadFile(objectKey string, bucketKey string, file io.ReadCloser) (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return uploadFile(v.host, objectKey, bucketKey, file, token)
}

func (v *vadaClient) DeleteFile(objectKey string, bucketKey string) error {
	token, err := v.getAccessToken()
	if err != nil {
		return err
	}

	return deleteFile(v.host, objectKey, bucketKey, token)
}

func (v *vadaClient) RegisterFile(b64Urn string) (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return registerFile(v.host, b64Urn, token)
}

func (v *vadaClient) GetDocumentInfo(b64Urn string, guid string) (*Json, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return getDocumentInfo(v.host, b64Urn, guid, token)
}

func (v *vadaClient) GetSheetItem(b64UrnAndItemPath string) (*http.Response, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return getSheetItem(v.host, b64UrnAndItemPath, token)
}

func (v *vadaClient) GetFile(objectKey string, bucketKey string) (*http.Response, error) {
	token, err := v.getAccessToken()
	if err != nil {
		return nil, err
	}

	return getSeedFile(v.host, objectKey, bucketKey, token)
}

/**
 * helpers
 */

func checkResponse(resp *http.Response, err error) error {
	if err != nil {
		return err
	}
	if resp.StatusCode >= 400 {
		body, _ := FromReadCloser(resp.Body)
		bodyStr, _ := body.ToString()
		return errors.New(fmt.Sprintf("statusCode: %d, status: %v, body: %v", resp.StatusCode, resp.Status, bodyStr))
	}
	return nil
}

func newRequest(method string, urlStr string, body io.Reader, accessToken string, contentType string) (*http.Request, error) {
	req, err := http.NewRequest(method, urlStr, body)
	if err != nil {
		return nil, err
	}
	if accessToken != "" {
		req.Header.Set("Authorization", "Bearer "+accessToken)
	}
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	return req, nil
}

func doStructuredJsonRequest(req *http.Request, dst interface{}) error {
	client := http.DefaultClient
	resp, err := client.Do(req)
	if resp != nil && resp.Body != nil {
		defer resp.Body.Close()
	}
	if err = checkResponse(resp, err); err != nil {
		return err
	}

	decoder := json.NewDecoder(resp.Body)
	if err = decoder.Decode(dst); err != nil {
		return err
	}

	return nil
}

func doAdhocJsonRequest(req *http.Request) (ret *Json, err error) {
	client := http.DefaultClient
	resp, err := client.Do(req)
	if resp != nil {
		if resp.Body != nil {
			defer resp.Body.Close()
		}
		err = checkResponse(resp, err)
		if err == nil {
			ret, err = FromReadCloser(resp.Body)
		}
	}
	return
}
