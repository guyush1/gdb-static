from pathlib import Path

import tarfile
import tempfile
import asyncio

import aiohttp
import aiohttp.client_exceptions

CHUNK_SIZE = 65536
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
