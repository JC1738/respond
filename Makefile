APP_NAME ?= ot-go-static
PORT0 ?= 9000
LOCALIP=$(shell ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | grep -v '192.168' | grep -v '172.17' | grep -v '172.16' | grep -v '10.10.22'  | awk '{print $1}')
TASK_HOST ?= $(LOCALIP)
DISCO_HOST ?= discovery-ci-uswest2.otenv.com
OT_LOGGING_REDIS_HOST ?= logging-qa-uswest2.otenv.com
OT_LOGGING_REDIS_PORT ?= 6379
OT_LOGGING_REDIS_LIST ?= logstash
OT_LOGGING_REDIS_TIMEOUT_MS ?= 5000
STATIC_INSTANCE ?= demo
SERVICE_TYPE ?= "static-test"
APP_HOST ?= $(shell hostname)
SHOULD_ANNOUNCE ?= true
DOCKER_RUN_PARAMS ?= --env="PORT0=$(PORT0)" -p="$(PORT0):$(PORT0)" --env="SERVICE_TYPE=$(SERVICE_TYPE)" --env="TASK_HOST=$(TASK_HOST)" --env="STATIC_INSTANCE=$(STATIC_INSTANCE)" --dns=10.0.0.104 --dns=10.0.0.103 --dns=10.0.0.102
DOCKERGO = docker run --rm -e CGO_ENABLED=0 -v $(PWD):/usr/src/myapp -v $(PWD):/go -w /usr/src/myapp golang:1.7
TAG ?= 10.0.0
CLUSTER ?= dev-ci-sf
print-%  : ; @echo $* = $($*)

include gc-deploy-tools/Makefile
  
sous-build:

	@status=$$(git status --porcelain); \
	if test "x$${status}" = x; then \
		echo "<html><body><P>" > static/version.html; \
		echo $(TAG) >> static/version.html; \
		echo "</P></body></html>" >> static/version.html; \
		git add static/version.html; \
		git commit -m "update version.html as part of sous-build to $(TAG)"; \
		git tag -a $(TAG) -m "tag sous build $(TAG)"; \
		sous build -tag $(TAG); \
	else \
		echo Working directory is dirty, no build will occur >&2; \
	fi

sous-deploy:
	sous deploy -cluster $(CLUSTER) -tag $(TAG) 

compile-mac:
	gox -osarch="darwin/amd64" -gcflags="-a" -verbose -output="main_local"

compile-linux:
	gox -osarch="linux/amd64" -gcflags="-a" -verbose -output="main_local"

compile-linux-386:
	gox -osarch="linux/386" -gcflags="-a" -verbose -output="main_local"

local-run:
	TASK_HOST=$(TASK_HOST) APP_HOST=$(APP_HOST) STATIC_INSTANCE=$(STATIC_INSTANCE) ./main_local

compile-run-mac: compile-mac local-run

compile-run-linux: compile-linux local-run

compile-go:
	rm -rf src
	rm -f main
	cp -r ./vendor ./src
	$(DOCKERGO) go build -a -installsuffix cgo -o main .

compile-run: compile-go docker-run

.PHONY: compile-mac compile-linux compile-linux-386 local-run compile-go compile-run compile-run-mac compile-run-linux sous-build sous-deploy
