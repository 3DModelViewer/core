package vada

const (
	Transient              = BucketPolicy("transient")
	Temporary              = BucketPolicy("temporary")
	Persistent             = BucketPolicy("persistent")
	bucketValidationRegexp = "[-_.a-z0-9]{3,128}"
)

type BucketPolicy string
