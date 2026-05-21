import subprocess
from pathlib import Path
from typing import Optional, Dict, List
from enum import StrEnum

class Archs(StrEnum):
    X86_64 = "x86_64"
    AARCH64 = "aarch64"
    ARM = "arm"
    POWERPC = "powerpc"
    MIPS = "mips"
    MIPSEL = "mipsel"

COMPILERS: Dict[Archs, str] = {
    Archs.X86_64: "g++",
    Archs.AARCH64: "aarch64-linux-gnu-g++",
    Archs.ARM: "arm-linux-gnueabi-g++",
    Archs.POWERPC: "powerpc-linux-gnu-g++",
    Archs.MIPS: "mips-linux-gnu-g++",
    Archs.MIPSEL: "mipsel-linux-gnu-g++",
}

EMULATORS: Dict[Archs, Optional[str]] = {
    Archs.AARCH64: "qemu-aarch64",
    Archs.ARM: "qemu-arm",
    Archs.POWERPC: "qemu-ppc",
    Archs.MIPS: "qemu-mips",
    Archs.MIPSEL: "qemu-mipsel",
}

DUMMY_CPP_PROG = \
"""
#include <iostream>
int main() {
    std::cout << "GDB test dummy binary" << std::endl;
    return 0;
}
"""

def create_emulated_cmd(emulator_prefix: Optional[str], *args) -> List[str]:
    cmd = list()
    if emulator_prefix:
        cmd.append(emulator_prefix)
    cmd.extend(args)
    return cmd

def run_cmd(cmd: List[str], assert_success: bool = True) -> subprocess.CompletedProcess:
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=assert_success)
        return res
    except subprocess.CalledProcessError as e:
        print(f"STDOUT:\n{e.stdout}")
        print(f"STDERR:\n{e.stderr}")
        raise e

def check_binary_properties(binary_path: Path, target_arch: Archs) -> None:
    file_cmd = ["file", str(binary_path)]
    res = run_cmd(file_cmd)
    output = res.stdout.lower()

    # Check for static link
    assert "statically linked" in output, f"{binary_path.name} is not statically linked! File output: {res.stdout.strip()}"

    # Check for target architecture
    arch_checks = {
        Archs.X86_64: lambda o: "x86-64" in o,
        Archs.AARCH64: lambda o: "aarch64" in o,
        Archs.ARM: lambda o: "arm" in o and "aarch64" not in o,
        Archs.POWERPC: lambda o: "powerpc" in o or "ppc" in o,
        Archs.MIPS: lambda o: "mips" in o and "lsb" not in o,
        Archs.MIPSEL: lambda o: "mips" in o and "lsb" in o,
    }

    assert target_arch in arch_checks, f"Unsupported architecture check: {target_arch}"
    assert arch_checks[target_arch](output), f"{binary_path.name} does not match expected architecture {target_arch}. File output: {res.stdout.strip()}"
