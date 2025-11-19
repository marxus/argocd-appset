#!/cmp/bin/yaegi
package main

import (
	"log"
	"net/http"
	"net/http/cgi"
)

func main() {
	// Serve the "fake" git repository over HTTP using `git http-backend`
	log.Fatalln(http.ListenAndServe("0.0.0.0:8080", &cgi.Handler{
		Path: "/usr/bin/git",
		Args: []string{"http-backend"},
		Env: []string{
			"GIT_HTTP_EXPORT_ALL=",
			"GIT_PROJECT_ROOT=/cmp/repo",
		},
	}))
}
