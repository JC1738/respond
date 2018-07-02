PORT0 ?= 9000
LOCALIP=$(shell ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | grep -v '192.168' | grep -v '172.17' | grep -v '172.16' | grep -v '10.10.22'  | awk '{print $1}')
TASK_HOST ?= $(LOCALIP)
DOCKER_RUN_PARAMS ?= --env="PORT0=$(PORT0)" -p="$(PORT0):$(PORT0)" --env="TASK_HOST=$(TASK_HOST)"
DOCKERGO = docker run --rm -e CGO_ENABLED=0 -v $(PWD):/usr/src/myapp -v $(PWD):/go -w /usr/src/myapp golang:1.10.1
TAG ?= 10.0.0
CLUSTER ?= dev-ci-sf
print-%  : ; @echo $* = $($*)

sous-build: tag-build
	sous build -tag $(TAG)

tag-build:

	@status=$$(git status --porcelain); \
	if test "x$${status}" = x; then \
		echo "<html><body><P>" > static/version.html; \
		echo $(TAG) >> static/version.html; \
		echo "</P></body></html>" >> static/version.html; \
		git add static/version.html; \
		git commit -m "update version.html as part of sous-build to $(TAG)"; \
		git tag -a $(TAG) -m "tag sous build $(TAG)"; \
		git push origin --tags; \
	else \
		echo Working directory is dirty, no build will occur >&2; \
	fi

sous-deploy:
	sous deploy -cluster $(CLUSTER) -tag $(TAG)

docker-build: tag-build
	docker build -tag docker.otenv.com/respond:$(TAG) .

docker-run:
	docker run $(DOCKER_RUN_PARAMS) -d -name respond docker.otenv.com/respond:$(TAG)

compile-linux:
	gox -osarch="linux/amd64" -gcflags="-a" -verbose -output="main"

local-run:
	TASK_HOST=$(TASK_HOST) PORT0=$(PORT0) ./main

compile-run-mac: compile-mac local-run

compile-run-linux: compile-linux local-run

compile-go:
	rm -rf src
	rm -f main
	cp -r ./vendor ./src
	$(DOCKERGO) go build -a -installsuffix cgo -o main .

compile-run: compile-go docker-run

.PHONY: compile-mac compile-linux compile-linux-386 local-run compile-go compile-run compile-run-mac compile-run-linux sous-build sous-deploy
