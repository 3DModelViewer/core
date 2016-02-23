package sheet

import (
	"errors"
	"github.com/modelhub/db/util"
	"github.com/modelhub/vada"
	"github.com/robsix/golog"
	. "github.com/robsix/json"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"time"
)

func newSheetStore(setName setName, get get, getForDocumentVersion getForDocumentVersion, globalSearch globalSearch, projectSearch projectSearch, getRole util.GetRole, vada vada.VadaClient, log golog.Log) SheetStore {
	return &sheetStore{
		setName:          setName,
		get:             get,
		getForDocumentVersion:  getForDocumentVersion,
		getRole:         getRole,
		globalSearch: globalSearch,
		projectSearch: projectSearch,
		vada:            vada,
		log:             log,
	}
}

type sheetStore struct {
	setName                setName
	get             	   get
	getForDocumentVersion  getForDocumentVersion
	getRole         	   util.GetRole
	globalSearch 		   globalSearch
	projectSearch 		   projectSearch
	vada            	   vada
	log             	   golog.Log
}

func (dvs *documentVersionStore) Get(forUser string, ids []string) ([]*DocumentVersion, error) {
	if docVers, err := dvs.get(forUser, ids); err != nil {
		dvs.log.Error("DocumentVersionStore.Get error: forUser: %q ids: %v error: %v", forUser, ids, err)
		return nil, err
	} else {
		dvs.log.Info("DocumentVersionStore.Get success: forUser: %q ids: %v", forUser, ids)
		return convertToPublicFormat(docVers), nil
	}
}

func (dvs *documentVersionStore) GetForDocumentVersion(forUser string, id string, offset int, limit int, sortBy sortBy) ([]*DocumentVersion, int, error) {
	if docVers, totalResults, err := dvs.getForDocument(forUser, id, offset, limit, sortBy); err != nil {
		dvs.log.Error("DocumentVersionStore.GetForDocument error: forUser: %q id: %q offset: %d limit: %d sortBy: %q error: %v", forUser, id, offset, limit, sortBy, err)
		return convertToPublicFormat(docVers), totalResults, err
	} else {
		dvs.log.Info("DocumentVersionStore.GetForDocument success: forUser: %q id: %q offset: %d limit: %d sortBy: %q totalResults: %d", forUser, id, offset, limit, sortBy, totalResults)
		return convertToPublicFormat(docVers), totalResults, nil
	}
}
