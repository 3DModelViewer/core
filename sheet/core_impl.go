package sheet

import (
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	"net/http"
)

func newSheetStore(setName setName, get get, getForDocumentVersion getForDocumentVersion, globalSearch globalSearch, projectSearch projectSearch, vada vada.VadaClient, log golog.Log) SheetStore {
	return &sheetStore{
		setName: setName,
		get:     get,
		getForDocumentVersion: getForDocumentVersion,
		globalSearch:          globalSearch,
		projectSearch:         projectSearch,
		vada:                  vada,
		log:                   log,
	}
}

type sheetStore struct {
	setName               setName
	get                   get
	getForDocumentVersion getForDocumentVersion
	globalSearch          globalSearch
	projectSearch         projectSearch
	vada                  vada.VadaClient
	log                   golog.Log
}

func (ss *sheetStore) SetName(forUser string, id string, newName string) error {
	if err := ss.setName(forUser, id, newName); err != nil {
		ss.log.Error("DocumentVersionStore.SetName error: forUser: %q id: %q newName: %q error: %v", forUser, id, newName, err)
		return err
	} else {
		ss.log.Info("DocumentVersionStore.SetName success: forUser: %q id: %q newName: %q", forUser, id, newName)
		return nil
	}
}

func (ss *sheetStore) GetItem(forUser string, id string, path string) (*http.Response, string, error) {
	if sheets, err := ss.get(forUser, []string{id}); err != nil || len(sheets) == 0 {
		ss.log.Error("SheetStore.GetItem error: forUser: %q id: %q path: %q error: %v", forUser, id, path, err)
		return nil, "", err
	} else {
		if res, err := ss.vada.GetSheetItem(sheets[0].BaseUrn + path); err != nil {
			ss.log.Error("SheetStore.GetItem error: forUser: %q id: %q baseUrn: %q path: %q error: %v", forUser, id, sheets[0].BaseUrn, path, err)
			return res, sheets[0].BaseUrn, err
		} else {
			ss.log.Info("SheetStore.GetItem success: forUser: %q id: %q path: %q", forUser, id, path)
			return res, sheets[0].BaseUrn, err
		}
	}
}

func (ss *sheetStore) Get(forUser string, ids []string) ([]*Sheet, error) {
	if sheets, err := ss.get(forUser, ids); err != nil {
		ss.log.Error("SheetStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		ss.log.Info("SheetStore.Get success: forUser: %q ids: %v", forUser, ids)
		return convertToPublicFormat(sheets), nil
	}
}

func (ss *sheetStore) GetForDocumentVersion(forUser string, documentVersion string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error) {
	if sheets, totalResults, err := ss.getForDocumentVersion(forUser, documentVersion, offset, limit, sortBy); err != nil {
		ss.log.Error("SheetStore.GetForDocumentVersion error: forUser: %q documentVersion: %q offset: %d limit: %d sortBy: %q error: %v", forUser, documentVersion, offset, limit, sortBy, err)
		return convertToPublicFormat(sheets), totalResults, err
	} else {
		ss.log.Info("SheetStore.GetForDocumentVersion success: forUser: %q documentVersion: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, documentVersion, offset, limit, sortBy, totalResults)
		return convertToPublicFormat(sheets), totalResults, nil
	}
}

func (ss *sheetStore) GlobalSearch(forUser string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error) {
	if sheets, totalResults, err := ss.globalSearch(forUser, search, offset, limit, sortBy); err != nil {
		ss.log.Error("SheetStore.GlobalSearch error: forUser: %q search: %q offset: %d limit: %d sortBy: %q error: %v", forUser, search, offset, limit, sortBy, err)
		return convertToPublicFormat(sheets), totalResults, err
	} else {
		ss.log.Info("SheetStore.GlobalSearch success: forUser: %q search: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, search, offset, limit, sortBy, totalResults)
		return convertToPublicFormat(sheets), totalResults, nil
	}
}

func (ss *sheetStore) ProjectSearch(forUser string, project string, search string, offset int, limit int, sortBy sortBy) ([]*Sheet, int, error) {
	if sheets, totalResults, err := ss.projectSearch(forUser, project, search, offset, limit, sortBy); err != nil {
		ss.log.Error("SheetStore.ProjectSearch error: forUser: %q project: %q search: %q offset: %d limit: %d sortBy: %q error: %v", forUser, project, search, offset, limit, sortBy, err)
		return convertToPublicFormat(sheets), totalResults, err
	} else {
		ss.log.Info("SheetStore.ProjectSearch success: forUser: %q project: %q search: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, project, search, offset, limit, sortBy, totalResults)
		return convertToPublicFormat(sheets), totalResults, nil
	}
}

func convertToPublicFormat(sheets []*Sheet_) []*Sheet {
	publicSheets := make([]*Sheet, 0, len(sheets))
	for _, s := range sheets {
		publicSheets = append(publicSheets, &Sheet{
			Id:              s.Id,
			DocumentVersion: s.DocumentVersion,
			Name:            s.Name,
			Thumbnails:      s.Thumbnails,
			Project:         s.Project,
			Manifest:        s.Manifest,
			Role:            s.Role,
		})
	}
	return publicSheets
}
