package documentversion

import (
	"errors"
	"github.com/modelhub/core/api/sheet"
	"github.com/modelhub/core/util"
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	. "github.com/robsix/json"
	"strings"
	"time"
)

func convertToPublicFormat(dvs []*_documentVersion) []*DocumentVersion {
	publicDvs := make([]*DocumentVersion, 0, len(dvs))
	for _, dv := range dvs {
		publicDvs = append(publicDvs, &DocumentVersion{
			Id:            dv.Id,
			Document:      dv.Document,
			Version:       dv.Version,
			Project:       dv.Project,
			Uploaded:      dv.Uploaded,
			UploadComment: dv.UploadComment,
			UploadedBy:    dv.UploadedBy,
			FileExtension: dv.FileExtension,
			Status:        dv.Status,
		})
	}
	return publicDvs
}

func performStatusCheck(dvs []*_documentVersion, bulkStatusUpdate bulkSetStatus, bulkSaveSheets bulkSaveSheets, statusCheckTimeOut time.Duration, vada vada.VadaClient, log golog.Log) []error {
	errChan := make(chan error)
	changeChan := make(chan *_documentVersion)
	successChan := make(chan *Json)
	timeOutChan := time.After(statusCheckTimeOut)
	checkCount := 0
	for _, e := range dvs {
		if e.Status == "registered" || e.Status == "pending" || e.Status == "inprogress" {
			go func(dv *_documentVersion) {
				log.Info("DocumentVersionStore performStatusCheck for docVer: %q ", dv.Id)
				statusJson, err := vada.GetDocumentInfo(util.ToBase64(dv.Urn), "")
				if err != nil {
					errChan <- err
					return
				}
				status, err := statusJson.String("status")
				if err != nil {
					log.Critical("DocumentVersionStore performStatusCheck, could not read status property error: %v", err)
					errChan <- err
					return
				}
				if dv.Status != status {
					dv.Status = status
					changeChan <- dv
					if dv.Status == "success" {
						statusJson.Set(dv.Id, documentVersionJsonProperty)
						statusJson.Set(dv.Project, projectJsonProperty)
						successChan <- statusJson
					}
				} else {
					errChan <- nil
					return
				}
			}(e)
			checkCount++
		}
	}
	errs := make([]error, 0, checkCount)
	changes := make([]*_documentVersion, 0, checkCount)
	successes := make([]*Json, 0, checkCount)
	for checkCount > 0 {
		timedOut := false
		select {
		case err := <-errChan:
			checkCount--
			if err != nil {
				errs = append(errs, err)
			}
		case dv := <-changeChan:
			checkCount--
			changes = append(changes, dv)
		case statusJson := <-successChan:
			successes = append(successes, statusJson)
		case <-timeOutChan:
			log.Warning("DocumentVersionStore performStatusCheck timed out after %v with %s open updates awaiting response", statusCheckTimeOut, checkCount)
			timedOut = true
		}
		if timedOut {
			break
		}
	}
	if len(changes) > 0 {
		if err := bulkStatusUpdate(changes); err != nil {
			errs = append(errs, err)
		}
	}
	if len(successes) > 0 {
		if err := extractAndSaveSheets(successes, bulkSaveSheets); err != nil {
			errs = append(errs, err...)
		}
	}
	if len(errs) != 0 {
		log.Error("DocumentVersionStore performStatusCheck error: %v", errs)
		return errs
	} else {
		return nil
	}
}

func getObjectsWithProperties(json *Json, matcher map[string]string) []*Json {
	var matches []*Json
	matchesGrowthFactor := 10
	addToMatches := func(match *Json) {
		if len(matches) == cap(matches) {
			matches = append(make([]*Json, 0, len(matches)+matchesGrowthFactor), matches...)
		}
		matches = append(matches, match)
	}

	var recurseThroughChildren func(obj *Json)
	recurseThroughChildren = func(obj *Json) {
		isMatch := true
		for propName, propValue := range matcher {
			if val := obj.MustString("", propName); val != propValue {
				isMatch = false
				break
			}
		}
		if isMatch {
			addToMatches(obj)
			return
		}
		for _, child := range obj.MustSlice([]interface{}{}, "children") {
			recurseThroughChildren(FromInterface(child))
		}
	}
	recurseThroughChildren(json)
	return matches
}

func extractSheetsFromDocJson(docVer string, project string, sheetMatcher map[string]string, manifestMatcher map[string]string, json *Json) ([]*sheet.Sheet_, error) {
	var extractedSheets []*sheet.Sheet_
	growthFactor := 10
	addToExtractedSheets := func(s *sheet.Sheet_) {
		if len(extractedSheets) == cap(extractedSheets) {
			extractedSheets = append(make([]*sheet.Sheet_, 0, len(extractedSheets)+growthFactor), extractedSheets...)
		}
		extractedSheets = append(extractedSheets, s)
	}

	sheets := getObjectsWithProperties(json, sheetMatcher)
	for _, s := range sheets {
		manifestObj := getObjectsWithProperties(s, manifestMatcher)
		if len(manifestObj) == 0 {
			return nil, errors.New("DocumentVersionStore etractSheetsFromDocJson: No manifest node found")
		} else if len(manifestObj) > 1 {
			return nil, errors.New("DocumentVersionStore etractSheetsFromDocJson: More than one manifest node found")
		} else {
			var baseUrn string
			var manifest string
			var thumbnails []string
			addToThumbnails := func(tn string) {
				if len(thumbnails) == cap(thumbnails) {
					thumbnails = append(make([]string, 0, len(thumbnails)+growthFactor), thumbnails...)
				}
				thumbnails = append(thumbnails, tn)
			}
			if fullUrnAndPath, err := manifestObj[0].String("urn"); err != nil {
				return nil, err
			} else {
				idx := strings.Index(fullUrnAndPath, "/")
				if idx == -1 {
					return nil, errors.New("DocumentVersionStore etractSheetsFromDocJson: Unexpected Urn format, no / character found during manifest path extraction")
				}
				baseUrn = fullUrnAndPath[:idx]
				manifest = fullUrnAndPath[idx:]
			}
			thumbnailObjs := getObjectsWithProperties(s, map[string]string{
				"role": "thumbnail",
			})
			for _, thumbObj := range thumbnailObjs {
				if fullUrnAndPath, err := thumbObj.String("urn"); err != nil {
					return nil, err
				} else {
					idx := strings.Index(fullUrnAndPath, "/")
					if idx == -1 {
						return nil, errors.New("DocumentVersionStore etractSheetsFromDocJson: Unexpected Urn format, no / character found during thumbnail path extraction")
					}
					addToThumbnails(fullUrnAndPath[idx:])
				}
			}
			addToExtractedSheets(&sheet.Sheet_{
				Sheet: sheet.Sheet{
					DocumentVersion: docVer,
					Project:         project,
					Name:            s.MustString("", "name"),
					Role:            s.MustString("", "role"),
					Thumbnails:      thumbnails,
					Manifest:        manifest,
				},
				BaseUrn: baseUrn,
			})
		}
	}
	return extractedSheets, nil
}

func extractAndSaveSheets(documents []*Json, bulkSaveSheets bulkSaveSheets) []error {
	sheets := make([]*sheet.Sheet_, 0, len(documents)*20)
	errs := []error{}
	for _, doc := range documents {
		if docVer, err := doc.String(documentVersionJsonProperty); err != nil {
			errs = append(errs, err)
			return errs
		} else if project, err := doc.String(projectJsonProperty); err != nil {
			errs = append(errs, err)
			return errs
		} else {
			for _, json := range documents {
				sheetMatcher := map[string]string{
					"type": "geometry",
					"role": "3d",
				}
				manifestMatcher := map[string]string{
					"mime": "application/autodesk-svf",
				}
				for i := 0; i < 2; i++ {
					if i == 1 {
						sheetMatcher = map[string]string{
							"type": "geometry",
							"role": "2d",
						}
						manifestMatcher = map[string]string{
							"mime": "application/autodesk-f2d",
						}
					}
					if nextBatchOfsheets, err := extractSheetsFromDocJson(docVer, project, sheetMatcher, manifestMatcher, json); err != nil {
						errs = append(errs, err)
					} else if len(nextBatchOfsheets) > 0 {
						sheets = append(sheets, nextBatchOfsheets...)
					}
				}
			}
		}
	}
	if len(sheets) > 0 {
		if err := bulkSaveSheets(sheets); err != nil {
			errs = append(errs, err)
		}
	}
	if len(errs) > 0 {
		return errs
	} else {
		return nil
	}
}
