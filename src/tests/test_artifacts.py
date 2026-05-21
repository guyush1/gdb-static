from pathlib import Path
from .misc import check_binary_properties, run_cmd, create_emulated_cmd, Archs

def test_gdb_properties(gdb_path: Path, target_arch: Archs):
    check_binary_properties(gdb_path, target_arch)

def test_gdbserver_properties(gdbserver_path: Path, target_arch: Archs):
    check_binary_properties(gdbserver_path, target_arch)

def test_gdb_disassembly(gdb_path: Path, compiled_dummy: Path, emulator_prefix: str):
    gdb_test_cmd = create_emulated_cmd(emulator_prefix,
                                       str(gdb_path),
                                       "--nx", "--batch",
                                       "-ex", f"file {compiled_dummy}",
                                       "-ex", "disas main")

    res = run_cmd(gdb_test_cmd)
    assert "Dump of assembler code for function main:" in res.stdout, f"GDB failed to disassemble 'main'. Output:\n{res.stdout}"

def test_gdb_python_integration(gdb_path: Path, build_type: str, emulator_prefix: str) -> None:
    py_test_cmd = create_emulated_cmd(emulator_prefix,
                                      str(gdb_path),
                                      "--nx", "--batch",
                                      "-ex", "python import pygments; import ctypes; print('PYTHON_OK')")
    res = run_cmd(py_test_cmd, assert_success=False)

    if build_type == "full":
        assert res.returncode == 0, f"Gdb failed with returncode {res.returncode}.\nstdout:\n{res.stdout}\nstderr:\n{res.stderr}"
        assert "PYTHON_OK" in res.stdout, f"Python verification failed for 'full' build.\nstdout:\n{res.stdout}\nstderr:\n{res.stderr}"
    else: # slim
        assert "Python scripting is not supported" in res.stderr,\
               f"Python support was expected to be disabled in 'slim' build, but the command succeeded!\nstdout:\n{res.stdout}\nstderr:\n{res.stderr}"
