package helper

import (
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/projectspaceversion"
	"github.com/modelhub/core/sheet"
	"github.com/modelhub/core/treenode"
	"github.com/robsix/golog"
	"time"
)

func NewHelper(tns treenode.TreeNodeStore, dvs documentversion.DocumentVersionStore, psvs projectspaceversion.ProjectSpaceVersionStore, ss sheet.SheetStore, batchGetTimeout time.Duration, log golog.Log) Helper {
	return &helper{
		tns:             tns,
		dvs:             dvs,
		psvs:            psvs,
		ss:              ss,
		batchGetTimeout: batchGetTimeout,
		log:             log,
	}
}

type helper struct {
	tns             treenode.TreeNodeStore
	dvs             documentversion.DocumentVersionStore
	psvs            projectspaceversion.ProjectSpaceVersionStore
	ss              sheet.SheetStore
	batchGetTimeout time.Duration
	log             golog.Log
}

func (h *helper) GetChildrenDocumentsWithLatestVersionAndFirstSheetInfo(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*DocumentNode, int, error) {
	if docs, totalResults, err := h.tns.GetChildren(forUser, folder, "document", offset, limit, treenode.SortBy(string(sortBy))); err != nil {
		return nil, totalResults, err
	} else {
		countDown := len(docs)
		timeOutChan := time.After(h.batchGetTimeout)
		res := make([]*DocumentNode, 0, totalResults)
		resVerChan := make(chan *struct {
			resIdx        int
			latestVersion *latestVersion
			err           error
		})
		for idx, doc := range docs {
			res = append(res, &DocumentNode{
				TreeNode: doc,
			})
			go func(idx int, doc *treenode.TreeNode) {
				vers, _, er := h.dvs.GetForDocument(forUser, doc.Id, 0, 1, documentversion.VersionDesc)
				resVer := &struct {
					resIdx        int
					latestVersion *latestVersion
					err           error
				}{
					resIdx:        idx,
					latestVersion: nil,
					err:           er,
				}
				if vers != nil && len(vers) > 0 {
					ver := vers[0]
					resVer.latestVersion = &latestVersion{
						Id:            ver.Id,
						FileType:      ver.FileType,
						FileExtension: ver.FileExtension,
						Status:        ver.Status,
						ThumbnailType: ver.ThumbnailType,
						SheetCount:    ver.SheetCount,
					}
					if ver.FileType == "lmv" && ver.Status == "success" {
						sheets, _, _ := h.ss.GetForDocumentVersion(forUser, ver.Id, 0, 1, sheet.NameAsc)
						if sheets != nil && len(sheets) > 0 {
							sheet := sheets[0]
							resVer.latestVersion.FirstSheet = &firstSheet{
								Id:         sheet.Id,
								Thumbnails: sheet.Thumbnails,
								Manifest:   sheet.Manifest,
								Role:       sheet.Role,
							}
						}
					}
				}
				resVerChan <- resVer
			}(idx, doc)
		}
		for countDown > 0 {
			timedOut := false
			select {
			case resVer := <-resVerChan:
				countDown--
				if resVer.latestVersion != nil {
					res[resVer.resIdx].LatestVersion = resVer.latestVersion
				}
			case <-timeOutChan:
				h.log.Warning("Helper.GetChildrenDocumentsWithLatestVersionAndFirstSheetInfo timed out after %v with %d open latest version requests awaiting response", h.batchGetTimeout, countDown)
				timedOut = true
			}
			if timedOut {
				break
			}
		}
		return res, totalResults, err
	}
}

func (h *helper) GetDocumentVersionsWithFirstSheetInfo(forUser string, document string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error) {
	if docVers, totalResults, err := h.dvs.GetForDocument(forUser, document, offset, limit, documentversion.SortBy(string(sortBy))); err != nil {
		return nil, totalResults, err
	} else {
		countDown := len(docVers)
		timeOutChan := time.After(h.batchGetTimeout)
		res := make([]*DocumentVersion, 0, totalResults)
		resSheetChan := make(chan *struct {
			resIdx     int
			firstSheet *firstSheet
			err        error
		})
		for idx, docVer := range docVers {
			res = append(res, &DocumentVersion{
				DocumentVersion: docVer,
			})
			if docVer.FileType == "lmv" && docVer.Status == "success" {
				go func(idx int, docVer *documentversion.DocumentVersion) {
					sheets, _, er := h.ss.GetForDocumentVersion(forUser, docVer.Id, 0, 1, sheet.NameAsc)
					resSheet := &struct {
						resIdx     int
						firstSheet *firstSheet
						err        error
					}{
						resIdx:     idx,
						firstSheet: nil,
						err:        er,
					}
					if sheets != nil && len(sheets) > 0 {
						sheet := sheets[0]
						resSheet.firstSheet = &firstSheet{
							Id:         sheet.Id,
							Thumbnails: sheet.Thumbnails,
							Manifest:   sheet.Manifest,
							Role:       sheet.Role,
						}
					}
					resSheetChan <- resSheet
				}(idx, docVer)
			} else {
				countDown--
			}
		}
		for countDown > 0 {
			timedOut := false
			select {
			case resSheet := <-resSheetChan:
				countDown--
				if resSheet.firstSheet != nil {
					res[resSheet.resIdx].FirstSheet = resSheet.firstSheet
				}
			case <-timeOutChan:
				h.log.Warning("Helper.GetDocumentVersionsWithFirstSheetInfo timed out after %v with %d open first sheet requests awaiting response", h.batchGetTimeout, countDown)
				timedOut = true
			}
			if timedOut {
				break
			}
		}
		return res, totalResults, err
	}
}

func (h *helper) GetChildrenProjectSpacesWithLatestVersion(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*ProjectSpaceNode, int, error) {
	if projSpaces, totalResults, err := h.tns.GetChildren(forUser, folder, "projectSpace", offset, limit, treenode.SortBy(string(sortBy))); err != nil {
		return nil, totalResults, err
	} else {
		countDown := len(projSpaces)
		timeOutChan := time.After(h.batchGetTimeout)
		res := make([]*ProjectSpaceNode, 0, totalResults)
		resVerChan := make(chan *struct {
			resIdx        int
			latestVersion *projectspaceversion.ProjectSpaceVersion
			err           error
		})
		for idx, projSpace := range projSpaces {
			res = append(res, &ProjectSpaceNode{
				TreeNode: projSpace,
			})
			go func(idx int, projSpace *treenode.TreeNode) {
				vers, _, er := h.psvs.GetForProjectSpace(forUser, projSpace.Id, 0, 1, projectspaceversion.VersionDesc)
				resVer := &struct {
					resIdx        int
					latestVersion *projectspaceversion.ProjectSpaceVersion
					err           error
				}{
					resIdx:        idx,
					latestVersion: nil,
					err:           er,
				}
				if vers != nil && len(vers) > 0 {
					ver := vers[0]
					resVer.latestVersion = &projectspaceversion.ProjectSpaceVersion{
						Id:                  ver.Id,
						ProjectSpace:        ver.ProjectSpace,
						Version:             ver.Version,
						Project:             ver.Project,
						Created:             ver.Created,
						CreateComment:       ver.CreateComment,
						CreatedBy:           ver.CreatedBy,
						Camera:              ver.Camera,
						ThumbnailType:       ver.ThumbnailType,
						SheetTransformCount: ver.SheetTransformCount,
					}
				}
				resVerChan <- resVer
			}(idx, projSpace)
		}
		for countDown > 0 {
			timedOut := false
			select {
			case resVer := <-resVerChan:
				countDown--
				if resVer.latestVersion != nil {
					res[resVer.resIdx].LatestVersion = resVer.latestVersion
				}
			case <-timeOutChan:
				h.log.Warning("Helper.GetChildrenProjectSpacesWithLatestVersion timed out after %v with %d open latest version requests awaiting response", h.batchGetTimeout, countDown)
				timedOut = true
			}
			if timedOut {
				break
			}
		}
		return res, totalResults, err
	}
}
