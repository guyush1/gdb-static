#!/usr/bin/env python3.14

from tempfile import TemporaryDirectory
from argparse import ArgumentParser
from pathlib import Path, PurePath
from urllib.parse import urlparse
from typing import Iterable

import os
import asyncio

from file_downloader import download_tarfile

# TODO: I am using a mirror from random university in germany because the offical mirror doesn't
#       work in my LAN specifically...
SOURCE_URLS=(
    "https://ftp.fau.de/gnu/libiconv/libiconv-1.17.tar.gz",
    "https://ftp.fau.de/gnu/gmp/gmp-6.3.0.tar.xz",
    "https://ftp.fau.de/gnu/mpfr/mpfr-4.2.1.tar.xz",
    "https://ftp.fau.de/gnu/ncurses/ncurses-6.5.tar.gz",
)

async def download_source(packages_dir: Path, url: str):
    remote_tar_name = PurePath(urlparse(url).path).name

    lib_ver_name = remote_tar_name.rpartition(".tar")[0]
    lib_name = remote_tar_name.partition("-")[0]

    if not (packages_dir / lib_name).exists():
        await download_tarfile(url, packages_dir)

        # Strip the version number from the library's folder.
        os.rename(packages_dir / lib_ver_name, packages_dir / lib_name)

async def download_sources(packages_dir: Path, sources: Iterable[str]):
    print(f"Downloading library sources: {', '.join(sources)}")

    async with asyncio.TaskGroup() as tg:
        for url in sources:
            tg.create_task(download_source(packages_dir, url))

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("packages_dir", type=Path)

    args = parser.parse_args()

    asyncio.run(download_sources(args.packages_dir, SOURCE_URLS))
