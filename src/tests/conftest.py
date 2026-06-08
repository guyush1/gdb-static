import os
import tempfile
import pytest
from pathlib import Path
from typing import Optional, Generator

from .misc import run_cmd, COMPILERS, EMULATORS, DUMMY_CPP_PROG, Archs

def pytest_addoption(parser):
    parser.addoption("--arch", action="store", default=None, choices=list(Archs), help="Target architecture")
    parser.addoption("--build-type", action="store", default=None, help="Build type (slim / full)")

@pytest.fixture(scope="session")
def target_arch(request) -> Archs:
    return request.config.getoption("--arch")

@pytest.fixture(scope="session")
def build_type(request) -> str:
    return request.config.getoption("--build-type")

# The root dir of the project
@pytest.fixture(scope="session")
def root_dir() -> Path:
    return Path(__file__).parent.parent.parent.resolve()

# proj_dir/build/artifacts/<artifact_dir>
@pytest.fixture(scope="session")
def artifacts_dir(root_dir: Path, target_arch: Archs, build_type: str) -> Path:
    return root_dir / "build" / "artifacts" / f"{target_arch}_{build_type}"

# proj_dir/build/artifacts/<artifact_dir>/gdb
@pytest.fixture(scope="session")
def gdb_path(artifacts_dir: Path) -> Path:
    return artifacts_dir / "gdb"

# proj_dir/build/artifacts/<artifact_dir>/gdbserver
@pytest.fixture(scope="session")
def gdbserver_path(artifacts_dir: Path) -> Path:
    return artifacts_dir / "gdbserver"

@pytest.fixture(scope="session")
def emulator_prefix(target_arch: Archs) -> Optional[str]:
    if target_arch == Archs.X86_64:
        return None
    return EMULATORS[target_arch]

@pytest.fixture(scope="session")
def compiled_dummy(target_arch: Archs) -> Generator[Path, None, None]:
    with tempfile.TemporaryDirectory(prefix=f"gdb_static_{target_arch}_") as tmpdir:
        build_dir = Path(tmpdir)
        dummy_src = build_dir / "test_dummy.cpp"
        dummy_src.write_text(DUMMY_CPP_PROG)

        compiler = COMPILERS[target_arch]
        dummy_bin = build_dir / f"test_dummy_{target_arch}"
        run_cmd([compiler, str(dummy_src), "-static", "-o", str(dummy_bin)])

        assert dummy_bin.exists(), f"Dummy binary was not compiled successfully to {dummy_bin}"    
        yield dummy_bin
