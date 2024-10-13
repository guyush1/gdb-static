ARCHS := x86_64 arm aarch64 powerpc
TARGETS := $(addprefix build-, $(ARCHS))

.PHONY: clean help download_packages build patch-gdb build-docker-image $(TARGETS)

help:
	@echo "Usage:"
	@echo "  make build"
	@echo ""

	@for target in $(TARGETS); do \
		echo "  $$target"; \
	done

	@echo ""
	@echo "  make clean"

build/build-docker-image.stamp: Dockerfile
	mkdir -p build
	docker build -t gdb-static .
	touch build/build-docker-image.stamp

build-docker-image: build/build-docker-image.stamp

build/download-packages.stamp: build/build-docker-image.stamp src/download_packages.sh
	mkdir -p build/packages
	docker run --user $(shell id -u):$(shell id -g) \
		--rm --volume .:/app/gdb gdb-static env TERM=xterm-256color \
		/app/gdb/src/download_packages.sh /app/gdb/build/packages
	touch build/download-packages.stamp

download-packages: build/download-packages.stamp

build/patch-gdb.stamp: build/build-docker-image.stamp src/gdb_static.patch build/download-packages.stamp
	docker run --user $(shell id -u):$(shell id -g) \
		--rm --volume .:/app/gdb gdb-static env TERM=xterm-256color \
		/app/gdb/src/patch_gdb.sh /app/gdb/build/packages/gdb /app/gdb/src/gdb_static.patch
	touch build/patch-gdb.stamp

patch-gdb: build/patch-gdb.stamp

build: $(TARGETS)

$(TARGETS): build-%: download-packages patch-gdb build-docker-image
	mkdir -p build
	docker run --user $(shell id -u):$(shell id -g) \
		--rm --volume .:/app/gdb gdb-static env TERM=xterm-256color \
		/app/gdb/src/build.sh $* /app/gdb/build/ /app/gdb/src/gdb_static.patch

clean:
	rm -rf build
# Kill and remove all containers of image gdb-static
	docker ps -a | grep -P "^[a-f0-9]+\s+gdb-static\s+" | awk '{print $$1}' | xargs docker rm -f 2>/dev/null || true
	docker rmi -f gdb-static 2>/dev/null || true
