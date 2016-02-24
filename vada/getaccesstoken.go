package vada

import (
	"net/url"
	"strings"
)

type _accessToken struct {
	Type    string `json:"token_type,omitempty"`
	Token   string `json:"access_token,omitempty"`
	Expires int    `json:"expires_in,omitempty"`
}

type accessToken struct {
	Type    string `json:"type,omitempty"`
	Token   string `json:"token,omitempty"`
	Expires int    `json:"expires,omitempty"`
}

func getAccessToken(host string, key string, secret string) (*accessToken, error) {
	form := url.Values{"client_id": {key}, "client_secret": {secret}, "grant_type": {"client_credentials"}}
	req, err := newRequest("POST", host+"/authentication/v1/authenticate", strings.NewReader(form.Encode()), "", "application/x-www-form-urlencoded")
	if err != nil {
		return nil, err
	}

	tmp := &_accessToken{}
	err = doStructuredJsonRequest(req, tmp)

	return &accessToken{Type: tmp.Type, Token: tmp.Token, Expires: tmp.Expires}, err
}
