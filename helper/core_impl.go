package helper

import (
	"time"
	"github.com/modelhub/core/treenode"
	"github.com/modelhub/core/documentversion"
	"github.com/modelhub/core/sheet"
	"github.com/robsix/golog"
)

func NewHelper(tns treenode.TreeNodeStore, dvs documentversion.DocumentVersionStore, ss sheet.SheetStore, batchGetTimeout time.Duration, log golog.Log) Helper {
	return &helper{
		tns: tns,
		dvs: dvs,
		ss: ss,
		batchGetTimeout: batchGetTimeout,
		log: log,
	}
}

type helper struct {
	tns treenode.TreeNodeStore
	dvs documentversion.DocumentVersionStore
	ss sheet.SheetStore
	batchGetTimeout time.Duration
	log golog.Log
}

func (h *helper) GetChildrenDocumentsWithLatestVersionAndFirstSheetInfo(forUser string, folder string, offset int, limit int, sortBy sortBy) ([]*DocumentNode, int, error) {
	if docs, totalResults, err := h.tns.GetChildren(forUser, folder, "document", offset, limit, treenode.SortBy(string(sortBy))); err != nil {
		return nil, totalResults, err
	} else {
		countDown := len(docs)
		timeOutChan := time.After(h.batchGetTimeout)
		res := make([]*DocumentNode, 0, totalResults)
		resVerChan := make(chan *struct{
			resIdx int
			latestVersion *latestVersion
			err error
		})
		for idx, doc := range docs {
			res = append(res, &DocumentNode{
				TreeNode: doc,
			})
			go func(idx int, doc *treenode.TreeNode) {
				vers, _, er := h.dvs.GetForDocument(forUser, doc.Id, 0, 1, documentversion.VersionDesc)
				resVer := &struct{
					resIdx int
					latestVersion *latestVersion
					err error
				}{
					resIdx: idx,
					latestVersion: nil,
					err: er,
				}
				if vers != nil && len(vers) > 0 {
					ver := vers[0]
					resVer.latestVersion = &latestVersion{
						Id: ver.Id,
						FileType: ver.FileType,
						FileExtension: ver.FileExtension,
						Status: ver.Status,
						ThumbnailType: ver.ThumbnailType,
					}
					if ver.FileType == "lmv" && ver.Status == "success" {
						sheets, _, _ := h.ss.GetForDocumentVersion(forUser, ver.Id, 0, 1, sheet.NameAsc)
						if sheets != nil && len(sheets) > 0 {
							sheet := sheets[0]
							resVer.latestVersion.FirstSheet = &firstSheet{
								Id: sheet.Id,
								Thumbnails: sheet.Thumbnails,
								Manifest: sheet.Manifest,
								Role: sheet.Role,
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
			case resVer := <- resVerChan:
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