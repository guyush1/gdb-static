#!/usr/bin/env python3.12

import requests
import tarfile
import os
import shutil

from pathlib import Path

ARCHS = {
    "x86_64" : "https://more.musl.cc/11/x86_64-linux-musl/x86_64-linux-musl-cross.tgz",
    "arm" : "https://more.musl.cc/10/x86_64-linux-musl/arm-linux-musleabi-cross.tgz",
    "aarch64" : "https://more.musl.cc/11/x86_64-linux-musl/aarch64-linux-musl-cross.tgz",
    "powerpc" : "https://more.musl.cc/11/x86_64-linux-musl/powerpc-linux-musl-cross.tgz",
    "mips" : "https://more.musl.cc/11/x86_64-linux-musl/mips-linux-musl-cross.tgz",
    "mipsel" : "https://more.musl.cc/11/x86_64-linux-musl/mipsel-linux-musl-cross.tgz",
}
CHUNK_SIZE = 65536
MUSL_TOOLCHAINS_DIR = Path("/musl-toolchains")
ENTRYPOINT = "/entrypoint.sh"

def download_file(url: str, filename: str):
    print(f"Downloading {filename}")
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(filename, "wb") as f:
            for chunk in r.iter_content(chunk_size=CHUNK_SIZE):
                f.write(chunk)
    print(f"{filename} downloaded.")

def extract_tarball(filename: str, dst: Path):
    print(f"Extracting {filename}")
    with tarfile.open(filename, "r:gz") as tar:
        tar.extractall(path=dst)
    print(f"{filename} extracted")

def add_to_path(curr_path: str, package_path: Path):
    new_path = str((package_path / "bin").resolve())
    if curr_path != "":
        return new_path + ":" + curr_path
    return new_path


def main():
    os.mkdir(MUSL_TOOLCHAINS_DIR)

    updated_path = ""
    for arch, url in ARCHS.items():
        filename = url.split("/")[-1]
        download_file(url, filename)
        extract_tarball(filename, MUSL_TOOLCHAINS_DIR)
        updated_path = add_to_path(updated_path, MUSL_TOOLCHAINS_DIR / filename.removesuffix(".tgz"))

    # Fix the x86_64 dynamic loader if needed:
    # Unfortunately, the internal gdb build scripts builds some binaries (that generate documentation)
    # in a dynamic manner.
    #
    # Because we may use a musl-based toolchain, this means that we need to set-up the dynamic loader.
    # The fix may seem a little hacky, but it is simple, and is the best we can do.
    if "x86_64" in ARCHS:
        x86_toolchain_name = ARCHS["x86_64"].split("/")[-1].removesuffix(".tgz")
        x86_toolchain_path = MUSL_TOOLCHAINS_DIR / x86_toolchain_name
        x86_loader_path = x86_toolchain_path / "x86_64-linux-musl" / "lib" / "libc.so"
        shutil.copy2(x86_loader_path, "/lib/ld-musl-x86_64.so.1")

    # Create the entrypoint with the updated path.
    with open(ENTRYPOINT, mode="w") as f:
        f.write(
f"""#!/usr/bin/env bash
export PATH="$PATH:{updated_path}"
exec "$@"
""")

    # Make sure we can execute the entrypoint.
    os.chmod(ENTRYPOINT, 0o755)

    # Append the path to bash.bashrc so that other users will have these paths.
    with open("/etc/bash.bashrc", mode="a") as f:
        f.write(f"\nexport PATH=\"$PATH:{updated_path}\"")


if __name__ == "__main__":
    main()
