#!/appset/yaegi
package main

import (
	"os"
	"log"
	"net/http"
	"net/http/cgi"

)

func main() {
	log.Fatalln(http.ListenAndServe(os.Getenv("APPSET_CMP_SERVEGIT_ADDR"), &cgi.Handler{
		Path: "/usr/bin/git",
		Args: []string{"http-backend"},
		Env: []string{
			"GIT_HTTP_EXPORT_ALL=",
			"GIT_PROJECT_ROOT=/appset/repo",
		},
	}))
}
