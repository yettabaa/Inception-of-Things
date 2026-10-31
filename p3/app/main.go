// Minimal HTTP app for Part 3: answers like Wil's playground so the same
// checks apply, and the VERSION baked at build time is the only difference
// between the v1 and v2 images.
package main

import (
	"fmt"
	"log"
	"net/http"
)

var version = "dev" // set with -ldflags "-X main.version=v1"

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"ok", "message": "%s"}`+"\n", version)
	})
	log.Printf("playground %s listening on :8888", version)
	log.Fatal(http.ListenAndServe(":8888", nil))
}
