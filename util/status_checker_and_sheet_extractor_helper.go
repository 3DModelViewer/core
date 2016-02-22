package util

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
		for _, child := range obj.MustArray([]interface{}{}, "children") {
			recurseThroughChildren(FromInterface(child))
		}
	}
	recurseThroughChildren(json)
	return matches
}

func statusCheckerAndSheetExtractorHelper(docVer string, project string, sheetMatcher map[string]string, manifestMatcher map[string]string, json *Json) ([]T, error) {
	var extractedSheets []T
	growthFactor := 10
	addToExtractedSheets := func(entity T) {
		if len(extractedSheets) == cap(extractedSheets) {
			extractedSheets = append(make([]T, 0, len(extractedSheets)+growthFactor), extractedSheets...)
		}
		extractedSheets = append(extractedSheets, entity)
	}

	sheets := getObjectsWithProperties(json, sheetMatcher)
	for _, sheet := range sheets {
		manifestObj := getObjectsWithProperties(sheet, manifestMatcher)
		if len(manifestObj) == 0 {
			return nil, &sheetJsonProcessingError{
				Json:          sheet,
				SearchMatcher: manifestMatcher,
				Message:       "No Manifest node found",
			}
		} else if len(manifestObj) > 1 {
			return nil, &sheetJsonProcessingError{
				Json:          sheet,
				SearchMatcher: manifestMatcher,
				Message:       "More than one Manifest node found",
			}
		} else {
			var baseUrn string
			var path string
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
					return nil, &unexpectedUrnFormatError{
						Urn: fullUrnAndPath,
					}
				}
				baseUrn = fullUrnAndPath[:idx]
				path = fullUrnAndPath[idx:]
			}
			thumbnailObjs := getObjectsWithProperties(sheet, map[string]string{
				"role": "thumbnail",
			})
			for _, thumbObj := range thumbnailObjs {
				if fullUrnAndPath, err := thumbObj.String("urn"); err != nil {
					return nil, err
				} else {
					idx := strings.Index(fullUrnAndPath, "/")
					if idx == -1 {
						return nil, &unexpectedUrnFormatError{
							Urn: fullUrnAndPath,
						}
					}
					addToThumbnails(fullUrnAndPath[idx:])
				}
			}
			addToExtractedSheets(&_sheet{
				Id:              uuid.NewV4().String(),
				DocumentVersion: docVer,
				Project:         project,
				Name:            sheet.MustString("", "name"),
				Role:            sheet.MustString("", "role"),
				Thumbnails:      thumbnails,
				BaseUrn:         baseUrn,
				Path:            path,
			})
		}
	}
	return extractedSheets, nil
}

func extractAndSaveSheets(documents []*Json) error {
	sheetSets := make([][]T, 0, len(documents)*2)
	totalSheetCount := 0
	aggErr := &sheetExtractionError{
		Errors: []error{},
	}
	for _, doc := range documents {
		if docVer, err := doc.String(DocumentVersionJsonProperty); err != nil {
			return err
		} else if project, err := doc.String(ProjectJsonProperty); err != nil {
			return err
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
					if sheets, err := extractSheetsFromDocJson(docVer, project, sheetMatcher, manifestMatcher, json); err != nil {
						aggErr.Errors = append(aggErr.Errors, err)
					} else if len(sheets) > 0 {
						totalSheetCount += len(sheets)
						sheetSets = append(sheetSets, sheets)
					}
				}
			}
		}
	}
	if totalSheetCount > 0 {
		entities := make([]T, 0, totalSheetCount)
		deleteKeyValuesSet := make([][]T, 0, len(documents))
		for _, sheetSet := range sheetSets {
			entities = append(entities, sheetSet...)
			deleteKeyValuesSet = append(deleteKeyValuesSet, []T{entities[0].(*_sheet).DocumentVersion})
		}
		store.Del([]string{_documentVersion_}, deleteKeyValuesSet)
		if err := store.Put(entities); err != nil {
			aggErr.Errors = append(aggErr.Errors, err)
		}
	}
	if len(aggErr.Errors) > 0 {
		return aggErr
	} else {
		return nil
	}
}
