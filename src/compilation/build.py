#!/usr/bin/env python3.14

from typing import Dict, List, Callable, Self
from enum import Enum
from dataclasses import dataclass, field
from argparse import ArgumentParser
from pathlib import Path
from contextlib import chdir
from contextlib import contextmanager
from shutil import copytree, rmtree
from collections import defaultdict

import tomllib
import sys
import shlex
import subprocess
import os

class CompilationArch(Enum):
    ARM = "arm"
    ARM64 = "aarch64"
    POWERPC = "powerpc"
    X64 = "x86_64"
    MIPS = "mips"
    MIPSEL = "mipsel"

class BuildVariant(Enum):
    SLIM = "slim"
    FULL = "full"

ARCH_HOSTS = {
    CompilationArch.ARM: "arm-linux-musleabi",
    CompilationArch.ARM64: "aarch64-linux-musl",
    CompilationArch.POWERPC: "powerpc-linux-musl",
    CompilationArch.MIPS: "mips-linux-musl",
    CompilationArch.MIPSEL: "mipsel-linux-musl",
    CompilationArch.X64: "x86_64-linux-musl",
}

@dataclass
class CompilationConfiguration:
    """
    This class is used to initialize libraries with data that is specific to this build but doesn't
    change, like an architecture and the build dir.
    """

    arch: CompilationArch
    python: str

    src_dir: Path
    build_dir: Path

    script_dir: Path = field(init=False)
    submodules_dir: Path = field(init=False)
    packages_dir: Path = field(init=False)

    HOST: str = field(init=False)

    CC: str = field(init=False)
    CXX: str = field(init=False)
    AR: str = field(init=False)

    def __post_init__(self):
        self.script_dir = self.src_dir / "compilation/"
        self.submodules_dir = self.src_dir / "submodule_packages/"
        self.packages_dir = self.build_dir / "packages/"

        if self.arch not in ARCH_HOSTS.keys():
            raise RuntimeError(f"Architecture {self.arch} isn't supported")

        self.HOST = ARCH_HOSTS[self.arch]

        self.CC = str(f"{self.HOST}-gcc")
        self.CXX = str(f"{self.HOST}-g++")
        self.AR = str(f"{self.HOST}-ar")

    def get_compilation_constants(self):
        return {
            "HOST":     self.HOST,
            "CC":       self.CC,
            "CXX":      self.CXX,
            "AR":       self.AR,

            "arch": self.arch.value,
            "python": self.python
        }

@dataclass
class Library:
    compilation_config: CompilationConfiguration
    source_path: Path
    commands: List[str]

    # If relative then it's relative to the build path.
    install_path: Path = Path("output")

    dependencies: List[Self] = field(default_factory=list)

    env_setup: Callable[[CompilationConfiguration, Dict[str, str]], None] = lambda _, __: None

    # If relative then it's relative to the install path.
    result_files: List[Path] = field(default_factory=list)

    build_suffix: str = ""

    additional_lib_paths: List[Path] = field(default_factory=list)
    additional_include_paths: List[Path] = field(default_factory=list)

    def __post_init__(self):
        self.source_path = self.source_path.resolve()
        self.build_path = self.source_path / f"build-{self.compilation_config.arch.value}{self.build_suffix}"
        self.install_path = self.build_path / self.install_path

    def __hash__(self) -> int:
        # This should work becuase we don't want more than one library per source directory.
        return hash(self.source_path.resolve())

    def get_missing_files(self) -> List[Path]:
        if len(self.result_files) == 0:
            return []

        return list(filter(lambda file: not (self.install_path / file).exists(), self.result_files))

    def should_compile(self) -> bool:
        return len(self.result_files) == 0 or len(self.get_missing_files()) != 0

    def get_env(self) -> Dict[str, str]:
        library_env = defaultdict(str)
        self.env_setup(self.compilation_config, library_env)

        for lib_path in [self.install_path / "lib"] + self.additional_lib_paths:
            library_env["LDFLAGS"] += " " + shlex.quote(f"-L{lib_path}")

        for include_path in [self.install_path / "include"] + self.additional_include_paths:
            compilation_flag = " " + shlex.quote(f"-I{include_path}")

            library_env["CFLAGS"] = compilation_flag
            library_env["CXXFLAGS"] = compilation_flag

        return library_env

    def get_recursive_dependencies(self) -> List[Library]:
        """
        We don't use set because it doesn't guarantee order, so the order of the dependencies will
        change which automake doesn't accept so caching won't work.
        """
        dependencies: List[Library] = []

        for dependency in self.dependencies:
            dependencies.append(dependency)
            dependencies.extend(dependency.get_recursive_dependencies())

        return list(dict.fromkeys(dependencies))

    def build(self, lib_name: str):
        if not self.source_path.exists():
            raise FileNotFoundError()

        build_path = self.build_path
        build_path.mkdir(exist_ok=True)

        if not self.should_compile():
            print(f"Skipping {lib_name}: Files {self.result_files} already exist")
            return

        compilation_env = {
            "LDFLAGS": "-s",
            "CFLAGS": "-Os",
            "CXXFLAGS": "-Os",
            "PATH": os.environ["PATH"],
            **self.compilation_config.get_compilation_constants(),
            "install": str(build_path / self.install_path),
            "src": str(self.source_path)
        }

        # Setup the environment from all of the dependencies, including the current library!
        # Wouldn't work for env variables who aren't space seperated, like PATH.
        for dependency in self.get_recursive_dependencies() + [self]:
            for var_name, var_value in dependency.get_env().items():
                if var_name in compilation_env:
                    compilation_env[var_name] += " " + var_value
                else:
                    compilation_env[var_name] = var_value

        with chdir(self.source_path), scoped_compilation_title(lib_name):
            for command_tmpl in self.commands:
                command = command_tmpl.format(**compilation_env)
                subprocess.run(command, shell=True, env=compilation_env, check=True, cwd=build_path)

            if len(missing_files := self.get_missing_files()) > 0:
                raise RuntimeError(f"Failed to compile {lib_name}, missing files: {missing_files}")

def title_print(message: str, color: str = ""):
    message_with_border = f"# {message} #"
    print(color + '#' * len(message_with_border))
    print(message_with_border)
    print('#' * len(message_with_border) + "\033[0m")

@contextmanager
def scoped_compilation_title(name: str):
    title_print(f"Compiling {name}", color="\033[36m")
    try:
        yield None
        title_print(f"Finished compiling {name}", color="\033[32m")
    except Exception as e:
        title_print(f"Failed to compile {name}", color="\033[31m")
        raise e

def python_env_setup(compilation_config: CompilationConfiguration, current_env: Dict[str, str]):
    # Basic env setup.
    current_env.update({
        "LINKFORSHARED": " ",
        "MODULE_BUILDTYPE": "static",
        "CONFIG_SITE": f"{compilation_config.script_dir / 'static-python.site'}",
        "CURSES_LIBS": "-lncursesw",
        "PANEL_LIBS": "-lpanelw",
        "ZLIB_LIBS": "-lz",
    })

    current_env["CFLAGS"] += " -static "
    current_env["LDFLAGS"] += " -static "
    current_env["LIBS"] = current_env.get("LIBS", "") + " -lexpat -lffi -llzma -lpanelw -lncursesw -lz "

    # Frozen modules setup.
    with open(compilation_config.script_dir / "frozen_python_modules.txt", "r") as frozen_modules_file:
        # Support comments that start with '#' in the file that was read.
        modules = [i.strip().partition('#')[0] for i in frozen_modules_file.readlines()]

        modules.append(f"<gdb.**.*>: gdb = {compilation_config.submodules_dir}/binutils-gdb/gdb/python/lib/")
        modules.append(f"<pygments.**.*>: pygments = {compilation_config.submodules_dir}/pygments/")

    current_env["EXTRA_FROZEN_MODULES"] = ";".join(i for i in modules if len(i) > 0)

def initialize_libraries(compilation_config: CompilationConfiguration, build_config: dict, build_variant: BuildVariant, bfd_arches: str):
    libraries = {
        "libiconv": Library(
            compilation_config,
            compilation_config.packages_dir / "libiconv",
            commands=[
                "../configure --enable-static --host={HOST} --prefix={install}",
                "make -j$(nproc)",
                "make install"
            ],
            result_files=[Path("lib/libiconv.a")]
        ),
        "lzma": Library(
            compilation_config,
            compilation_config.submodules_dir / "xz",
            commands=[
                "cd .. && ./autogen.sh",
                "../configure --enable-static --host={HOST} --prefix={install}",
                "make -j$(nproc)",
                "make install"
            ],
            result_files=[Path("lib/liblzma.a")]
        ),
        "gmp": Library(
            compilation_config,
            compilation_config.packages_dir / "gmp",
            commands=[
                "../configure --enable-static --host={HOST} --prefix={install}",
                "make -j$(nproc)",
                "make install"
            ],
            result_files=[Path("lib/libgmp.a")]
        ),
        "ncurses": Library(
            compilation_config,
            compilation_config.packages_dir / "ncurses",
            commands=[
                "../configure --enable-static --host={HOST} --prefix={install} --enable-widec --with-default-terminfo-dir='/usr/share/terminfo'",
                "make -j$(nproc)",
                "make install.includes install.libs"
            ],
            result_files=[Path("lib/libncursesw.a"), Path("lib/libpanelw.a")]
        ),
        "expat": Library(
            compilation_config,
            compilation_config.submodules_dir / "libexpat",
            commands=[
                "../expat/buildconf.sh ../expat/",
                "../expat/configure --enable-static '--host={HOST}' '--prefix={install}'",
                "make -j$(nproc)",
                "make install"
            ],
            result_files=[Path("lib/libexpat.a")]
        )
    }

    # Add libraries with dependencies.

    libraries["mpfr"] = Library(
        compilation_config,
        compilation_config.packages_dir / "mpfr",
        commands=[
            f"../configure --enable-static --prefix={{install}} --host={{HOST}} --with-gmp={libraries["gmp"].install_path}",
            "make -j$(nproc)",
            "make install"
        ],
        result_files=[Path("lib/libmpfr.a")]
    )

    gdb_dependencies = list(libraries.values())

    # Build configuration file dependant libraries.

    full_build_configs = build_config['full_build']
    is_cross_arch_debugging: bool = full_build_configs["cross_arch_debugging"]
    is_building_python: bool = full_build_configs["python_support"]

    # Add libraries with dependencies
    if build_variant == BuildVariant.FULL:
        full_build_configs = build_config['full_build']
        is_cross_arch_debugging: bool = full_build_configs["cross_arch_debugging"]
        is_building_python: bool = full_build_configs["python_support"]

        gdb_flags = []
        if is_cross_arch_debugging:
            gdb_flags.extend([
                f"--enable-targets={bfd_arches}",
                "--enable-64-bit-bfd",
                "--disable-sim",
            ])

        if is_building_python:
            libraries["libffi"] = Library(
                compilation_config,
                compilation_config.submodules_dir / "libffi",
                commands=[
                    "cd .. && ./autogen.sh",
                    "CFLAGS='{CFLAGS} -DNO_JAVA_RAW_API' ../configure --enable-silent-rules --enable-static --disable-shared --disable-docs --host={HOST} --prefix={install}",
                    "make -j$(nproc)",
                    "make install"
                ],
                result_files=[Path("lib/libffi.a")]
            )
            libraries["zlib"] = Library(
                compilation_config,
                compilation_config.submodules_dir / "zlib",
                commands=[
                    "{src}/configure --static --prefix={install}",
                    "make install"
                ],
                result_files=[Path("lib/libz.a")]
            )
            libraries["python"] = Library(
                compilation_config,
                compilation_config.submodules_dir / "cpython-static",
                env_setup=python_env_setup,
                # We install Python to the build path because otherwise Python breaks and sets incorrect
                # paths for libhacl in python-configure.
                install_path=Path("."),
                dependencies=[
                    libraries["libffi"],
                    libraries["zlib"],
                    libraries["lzma"],
                    libraries["ncurses"],
                    libraries["expat"]
                ],
                commands=[
                    """
                    ../configure \
                        --prefix={install} \
                        --disable-test-modules \
                        --with-ensurepip=no \
                        --without-decimal-contextvar \
                        --build=$(gcc -dumpmachine) \
                        --host={HOST} \
                        --with-build-python="/usr/bin/{python}" \
                        --disable-ipv6 \
                        --disable-shared
                    """,
                    "{python} ../Tools/build/freeze_modules.py",
                    "make regen-frozen",
                    "make -j$(nproc)",
                    "make install"
                ],
                result_files=[Path("bin/python3-config"), Path(f"lib/lib{compilation_config.python}.a")]
            )
            gdb_dependencies.append(libraries["python"])
            gdb_flags.append(
                f"--with-python={libraries["python"].install_path / "bin/python3-config"}",
            )
    else:
        gdb_flags = ["--without-python"]

    install_configs = build_config['install']
    program_suffix: str = install_configs['executable_suffix']
    if len(program_suffix) > 0:
        gdb_flags.append("--program-suffix=" + program_suffix)

    libraries["gdb"] = Library(
        compilation_config,
        compilation_config.submodules_dir / "binutils-gdb",
        build_suffix=f"-{build_variant.value}",
        dependencies=gdb_dependencies,
        commands = [
            f"""
            ../configure \
                    --prefix={{install}} \
                    --enable-static \
                    --with-static-standard-libraries \
                    --disable-inprocess-agent \
                    --enable-tui \
                    --with-system-zlib \
                    --with-lzma=yes \
                    --with-expat \
                    --with-libiconv-type=static \
                    --with-libexpat-type=static \
                    --with-liblzma="{libraries["lzma"].install_path}" \
                    --with-libiconv="{libraries["libiconv"].install_path}" \
                    --with-gmp="{libraries["gmp"].install_path}" \
                    --with-mpfr="{libraries["mpfr"].install_path}" \
                    --with-liblzma-type="static" \
                    "--host={{HOST}}" \
                    {" ".join(shlex.quote(i) for i in gdb_flags)}
            """,
            "make -j$(nproc)",
            "make install-host-nogcc"
        ],
        result_files=[Path("bin/gdb"), Path("bin/gdbserver")]
    )

    return libraries

def main():
    PYTHON_VERSION = os.getenv("PYTHON_VERSION")
    if PYTHON_VERSION is None:
        print("Error: 'PYTHON_VERSION' - The python version to compile and use for the build process, must be defined")
        sys.exit(1)

    parser = ArgumentParser()
    parser.add_argument("architecture", type=CompilationArch, choices=[i for i in CompilationArch])
    parser.add_argument("build_dir", type=Path)
    parser.add_argument("src_dir", type=Path)
    parser.add_argument("build_variant", type=BuildVariant, choices=[i for i in BuildVariant])
    parser.add_argument("bfd_arches", type=str)

    args = parser.parse_args()

    # Setup compilation environment.
    compilation_config = CompilationConfiguration(
        args.architecture,
        PYTHON_VERSION,
        args.src_dir,
        args.build_dir
    )

    # An easy way to configure the full build without needing to modify docker arguments or
    # parts of this file to ahieve the desired result.
    with open(compilation_config.script_dir / "build_conf.toml", "rb") as full_build_config_file:
        build_config_dict = tomllib.load(full_build_config_file)

    libraries = initialize_libraries(compilation_config, build_config_dict, args.build_variant, args.bfd_arches)
    for lib_name, library in libraries.items():
        library.build(lib_name)

    arch_artifacts_dir = compilation_config.build_dir / "artifacts" / compilation_config.arch.value
    rmtree(arch_artifacts_dir, ignore_errors=True)

    copytree(libraries["gdb"].install_path / "bin", arch_artifacts_dir)
    print(f"Copied artifacts to: {arch_artifacts_dir}")

if __name__ == "__main__":
    main()