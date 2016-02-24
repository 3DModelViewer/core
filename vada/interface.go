package vada

import (
	. "github.com/robsix/json"
	"io"
	"net/http"
)

type VadaClient interface {
	CreateBucket(bucketKey string, policyKey BucketPolicy) (*Json, error)
	DeleteBucket(bucketKey string) error
	GetBucketDetails(bucketKey string) (*Json, error)
	GetSupportedFormats() (*Json, error)
	UploadFile(objectKey string, bucketKey string, file io.ReadCloser) (*Json, error)
	DeleteFile(objectKey string, bucketKey string) error
	RegisterFile(b64Urn string) (*Json, error)
	GetDocumentInfo(b64Urn string, guid string) (*Json, error)
	GetSheetItem(b64UrnAndItemPath string) (*http.Response, error)
	GetFile(objectKey string, bucketKey string) (*http.Response, error)
}
