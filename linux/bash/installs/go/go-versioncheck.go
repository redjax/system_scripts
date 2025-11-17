package main

// Simple Go script to get the latest version of Go from https://go.dev/dl/?mode=json.
//
// Parses the JSON data into readable terminal output. You can control the output with
// flags. --latest shows only the latest release, --local shows only releases relevant
// to the current machine's platform, and --simple prints only the Go version number, i.e.
// 0.0.0

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"runtime"
	"sort"
	"strings"
)

var (
	goJsonUrl = "https://go.dev/dl/?mode=json"
)

type GoRelease struct {
	Version string `json:"version"`
	Stable  bool   `json:"stable"`
	Files   []struct {
		Filename string `json:"filename"`
		OS       string `json:"os"`
		Arch     string `json:"arch"`
		Kind     string `json:"kind"`
		Size     int64  `json:"size"`
	} `json:"files"`
}

func main() {
	// Parse user inputs
	latestFlag := flag.Bool("latest", false, "Show only the latest release")
	localFlag := flag.Bool("local", false, "Show only releases for current OS/arch")
	simpleFlag := flag.Bool("simple", false, "Print only version numbers")
	flag.Parse()

	resp, err := http.Get(goJsonUrl)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	var releases []GoRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		panic(err)
	}

	// Filter for local platform if --local provided
	if *localFlag {
		os := runtime.GOOS
		arch := runtime.GOARCH

		for i := range releases {
			var files []struct {
				Filename string `json:"filename"`
				OS       string `json:"os"`
				Arch     string `json:"arch"`
				Kind     string `json:"kind"`
				Size     int64  `json:"size"`
			}

			for _, f := range releases[i].Files {
				if f.OS == os && f.Arch == arch {
					files = append(files, f)
				}
			}

			releases[i].Files = files
		}
	}

	// Show only the latest stable release if --latest provided
	if *latestFlag {
		var stableReleases []GoRelease

		for _, r := range releases {
			if r.Stable {
				stableReleases = append(stableReleases, r)
			}
		}

		// Sort descending by version string (lexical sort works since stable releases use "goX.Y.Z")
		sort.SliceStable(stableReleases, func(i, j int) bool {
			return stableReleases[i].Version > stableReleases[j].Version
		})

		if len(stableReleases) > 0 {
			releases = stableReleases[:1]
		} else {
			releases = nil
		}
	}

	// Print results
	for _, r := range releases {
		if *simpleFlag {
			fmt.Println(strings.TrimPrefix(r.Version, "go"))
			continue
		}

		fmt.Printf("%s (stable: %v)\n", r.Version, r.Stable)

		for _, f := range r.Files {
			fmt.Printf("  %s (%s/%s, %s, %.1f MB)\n",
				f.Filename, f.OS, f.Arch, f.Kind, float64(f.Size)/1024/1024)
		}
	}
}
