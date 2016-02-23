package main

import (
	"github.com/modelhub/core/vada"
	"github.com/robsix/golog"
	"net/http"
	"encoding/base64"
)

const (
	vadaHost = "https://developer.api.autodesk.com"
	clientKey    = "vzZyhg9MZwhZhptG6JqCeR6gQorM8xvW"
	clientSecret = "Xc900b546fdb941f"
	bucketName   = "transient_01"
)

func main() {
	log := golog.NewConsoleLog(0)
	vadaClient := vada.NewVadaClient(vadaHost, clientKey, clientSecret, log)

	vadaClient.CreateBucket(bucketName, vada.Transient)
	vadaClient.GetBucketDetails(bucketName)
	vadaClient.GetSupportedFormats()

	http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		file, header, _ := r.FormFile("file")
		obj, err := vadaClient.UploadFile(header.Filename, bucketName, file)
		log.Info("%v %v", obj, err)
		urn, _ := obj.String("objectId")
		urn = base64.StdEncoding.EncodeToString([]byte(urn))
		vadaClient.RegisterFile(urn)
		vadaClient.GetDocumentInfo(urn, "")
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(`
			<!DOCTYPE html>
			<html>
				<head>
					<title>upload test</title>
					<meta charset="utf-8">
					<script>
						function uploadFile(){
							var data = new FormData();
							fileInput = document.getElementById("file");
							data.append("file", fileInput.files[0], fileInput.files[0].name);
							var http = new XMLHttpRequest();
							http.open("POST", "/upload", true);
							http.send(data);
							http.onload = function() {
								console.log(http);
							}
						}
					</script>
				</head>
				<body>
					<div>
						<input id="file" type="file" name="file">
						<button onclick="uploadFile()">Upload File</button>
					</div>

				</body>
			</html>
		`))
	})

	log.Info("Server Listening on localhost:8080")
	http.ListenAndServe(":8080", nil)
}
