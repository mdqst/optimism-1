import 'git.just'

# Set fuzzing ldflags for Darwin
FUZZLDFLAGS := if os() == "macos" { "-ldflags=-extldflags=-Wl,-ld_classic" } else { "" }

TARGETOS := env('GOOS', `go env GOOS`)
TARGETARCH := env('GOARCH', `go env GOARCH`)

GOBUILD := "env GO111MODULE=on GOOS=" + TARGETOS + " GOARCH=" + TARGETARCH + " CGO_ENABLED=0 go build -v"
GOTEST := "go test -v"
GOFUZZ := GOTEST + " " + FUZZLDFLAGS + " -run NOTAREALTEST"