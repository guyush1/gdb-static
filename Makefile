ARCHS := x86_64 arm aarch64 powerpc mips mipsel
GDB_BFD_ARCHS := $(shell echo $(ARCHS) | awk '{for(i=1;i<=NF;i++) $$i=$$i"-linux"; print}' OFS=,)

BASE_BUILD_TARGETS := $(addprefix build-, $(ARCHS))

SLIM_BUILD_TARGETS := $(addsuffix -slim, $(BASE_BUILD_TARGETS))
FULL_BUILD_TARGETS := $(addsuffix -full, $(BASE_BUILD_TARGETS))
ALL_BUILD_TARGETS := $(SLIM_BUILD_TARGETS) $(FULL_BUILD_TARGETS)

BASE_TEST_TARGETS := $(addprefix test-, $(ARCHS))

SLIM_TEST_TARGETS := $(addsuffix -slim, $(BASE_TEST_TARGETS))
FULL_TEST_TARGETS := $(addsuffix -full, $(BASE_TEST_TARGETS))
ALL_TEST_TARGETS := $(SLIM_TEST_TARGETS) $(FULL_TEST_TARGETS)

BASE_PACK_TARGETS := $(addprefix pack-, $(ARCHS))

FULL_PACK_TARGETS := $(addsuffix -full, $(BASE_PACK_TARGETS))
SLIM_PACK_TARGETS := $(addsuffix -slim, $(BASE_PACK_TARGETS))
ALL_PACK_TARGETS := $(SLIM_PACK_TARGETS) $(FULL_PACK_TARGETS)

SUBMODULE_PACKAGES := $(wildcard src/submodule_packages/*)
BUILD_PACKAGES_DIR := "build/packages"

# We would like to run in interactive mode when avaliable (non-ci usually).
# This is disabled by the ci automation manually.
TTY_ARG ?= -it

.PHONY: clean help download_packages build build-docker-image $(ALL_BUILD_TARGETS) $(ALL_PACK_TARGETS) $(ALL_TEST_TARGETS)

.NOTPARALLEL: build pack

help:
	@echo "Usage:"
	@echo "  make build"
	@echo ""

	@for target in $(ALL_BUILD_TARGETS); do \
		echo "  $$target"; \
	done

	@echo ""
	@echo "  make clean"

build/build-docker-image.stamp: Dockerfile src/docker_utils/download_musl_toolchains.py
	mkdir -p build
	docker buildx build --tag gdb-static .
	touch build/build-docker-image.stamp

build-docker-image: build/build-docker-image.stamp

build/download-packages.stamp: build/build-docker-image.stamp src/compilation/download_packages.sh
	mkdir -p $(BUILD_PACKAGES_DIR)
	docker run $(TTY_ARG) --user $(shell id -u):$(shell id -g) \
		--rm --volume .:/app/gdb gdb-static env TERM=xterm-256color \
		/app/gdb/src/compilation/download_packages.sh /app/gdb/$(BUILD_PACKAGES_DIR)/
	touch build/download-packages.stamp

build/symlink-git-packages.stamp: $(SUBMODULE_PACKAGES)
	mkdir -p $(BUILD_PACKAGES_DIR)
	ln -sf $(addprefix /app/gdb/, $(SUBMODULE_PACKAGES)) $(BUILD_PACKAGES_DIR)/

symlink-git-packages: build/symlink-git-packages.stamp

download-packages: build/download-packages.stamp

build: $(ALL_BUILD_TARGETS)

$(SLIM_BUILD_TARGETS): build-%-slim:
	@BUILD_TYPE="slim" $(MAKE) _build-$*

$(FULL_BUILD_TARGETS): build-%-full:
	@BUILD_TYPE="full" GDB_BFD_ARCHS=$(GDB_BFD_ARCHS) $(MAKE) _build-$*

_build-%: symlink-git-packages download-packages build-docker-image
	mkdir -p build
	docker run $(TTY_ARG) --user $(shell id -u):$(shell id -g) \
		--rm --volume .:/app/gdb gdb-static env TERM=xterm-256color \
		/app/gdb/src/compilation/build.sh $* /app/gdb/build/ /app/gdb/src $(BUILD_TYPE) $(GDB_BFD_ARCHS)

pack: $(ALL_PACK_TARGETS)

$(SLIM_PACK_TARGETS): pack-%-slim:
	@BUILD_TYPE="slim" $(MAKE) _pack-$*

$(FULL_PACK_TARGETS): pack-%-full:
	@BUILD_TYPE="full" $(MAKE) _pack-$*

$(ALL_TEST_TARGETS): test-%:
	@TARGET="$*"; \
	TARGET_ARCH=$${TARGET%-*}; \
	TARGET_TYPE=$${TARGET##*-}; \
	python3 -m pytest -v src/tests/test_artifacts.py --arch="$$TARGET_ARCH" --build-type="$$TARGET_TYPE"

_pack-%: build-%-$(BUILD_TYPE)
	if [ ! -f "build/artifacts/gdb-static-$(BUILD_TYPE)-$*.tar.gz" ]; then \
		tar -czf "build/artifacts/gdb-static-$(BUILD_TYPE)-$*.tar.gz" -C "build/artifacts/$*_$(BUILD_TYPE)" .; \
	fi

clean-git-packages:
	git submodule foreach 'echo "$$sm_path" | grep "^src/submodule_packages/.*" && git clean -xffd && git restore .'

clean: clean-git-packages
	rm -rf build
# Kill and remove all containers of image gdb-static
	docker ps -a | grep -P "^[a-f0-9]+\s+gdb-static\s+" | awk '{print $$1}' | xargs docker rm -f 2>/dev/null || true
	docker rmi -f gdb-static 2>/dev/null || true
