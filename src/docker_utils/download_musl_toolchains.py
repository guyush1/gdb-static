#!/usr/bin/env python3.12

from pathlib import Path
from typing import List

import tarfile
import tempfile
import os
import shutil
import asyncio

import aiohttp
import aiohttp.client_exceptions

# NOTE: To add new architectures, you can use prebuilt toolchains from https://musl.cc/ or https://more.musl.cc/ .
# musl.cc / more.musl.cc are not used here since these websites blacklist Github Actions CI.
# As a result, I had to create the toolchains manually and include them here in order for our CI pipeline to pass.
ARCHS = {
    "x86_64" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/x86_64-linux-musl-cross.tgz",
    "arm" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/arm-linux-musleabi-cross.tgz",
    "aarch64" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/aarch64-linux-musl-cross.tgz",
    "powerpc" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/powerpc-linux-musl-cross.tgz",
    "mips" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/mips-linux-musl-cross.tgz",
    "mipsel" : "https://github.com/guyush1/musl-cross-make/releases/download/musl-gcc14/mipsel-linux-musl-cross.tgz",
}
CHUNK_SIZE = 65536
MUSL_TOOLCHAINS_DIR = Path("/musl-toolchains")
ENTRYPOINT = Path("/entrypoint.sh")

NUM_RETRIES = 3
RETRY_WAIT = 2

async def retry_middleware(req: aiohttp.ClientRequest, handler: aiohttp.ClientHandlerType, max_retries = NUM_RETRIES) -> aiohttp.ClientResponse:
    # If every retry ends in a timeoout, resp will not be defined. In such a case we want to raie
    # last timeout that has happened as we don't have a valid or invalid response to return.
    last_exception = None
    resp = None

    for _ in range(max_retries):
        try:
            resp = await handler(req)
            if resp.ok:
                return resp
        except aiohttp.client_exceptions.ConnectionTimeoutError as e:
            last_exception = e

        await asyncio.sleep(RETRY_WAIT)

    if resp is None:
        raise last_exception

    return resp

async def download_file(url: str, filename: str):
    async with aiohttp.ClientSession(middlewares=(retry_middleware,)) as session:
        async with session.get(url) as response:
            response.raise_for_status()
            with open(filename, 'wb') as f:
                async for data in response.content.iter_chunked(CHUNK_SIZE):
                    f.write(data)

def extract_tarfile(filename: str, dst: Path):
    with tarfile.open(filename, "r") as tar:
        tar.extractall(path=dst, filter='tar')

async def download_tarfile(tar_url: str, extraction_dir: Path):
    with tempfile.NamedTemporaryFile() as named_tempfile:
        await download_file(tar_url, named_tempfile.name)

        # Tarfile extraction is still being done synchronously.
        extract_tarfile(named_tempfile.name, extraction_dir)

    print(f"Downloaded & Extracted: {tar_url!r}")

async def download_archs() -> List[str]:
    print(f"Downloading toolchains for architectures: {', '.join(ARCHS.keys())}")

    async with asyncio.TaskGroup() as tg:
        for url in ARCHS.values():
            tg.create_task(download_tarfile(url, MUSL_TOOLCHAINS_DIR))

def add_to_path(curr_path: str, package_path: Path):
    new_path = str((package_path / "bin").resolve())
    if curr_path != "":
        return new_path + ":" + curr_path
    return new_path

def main():
    os.mkdir(MUSL_TOOLCHAINS_DIR)

    asyncio.run(download_archs())

    updated_path = "$PATH"
    for musl_arch_dir in os.scandir(MUSL_TOOLCHAINS_DIR):
        updated_path = add_to_path(updated_path, Path(musl_arch_dir.path))

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
