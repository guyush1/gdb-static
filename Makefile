
.PHONY: build clean

build:
	docker build -t gdb-static .
	docker create --name gdb-static-docker gdb-static || true # ignore if container already exists
	mkdir -p build
	docker cp "gdb-static-docker:/gdb" ./build/
	docker rm -f gdb-static-docker
	docker rmi gdb-static

clean:
	rm -rf build
	docker rm -f gdb-static-docker 2>/dev/null || true
