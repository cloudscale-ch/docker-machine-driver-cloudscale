.PHONY: build
build:
	@go build -mod vendor -o bin/docker-machine-driver-cloudscale

.PHONY: vendor
vendor:
	@go mod tidy
	@go mod vendor

.PHONY: snapshot
snapshot:
	@goreleaser release --snapshot --rm-dist
