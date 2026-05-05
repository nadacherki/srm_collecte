#!/usr/bin/env python
"""Run Dart/Flutter commands from Codex without inheriting a broken env.

The Codex Windows shell can contain both Path and PATH entries. Some process
launchers then hang or fail while Flutter also tries to touch SDK/AppData locks.
This wrapper rebuilds a clean environment, disables analytics, and enforces a
timeout so Dart/Flutter commands cannot stay stuck indefinitely.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


DEFAULT_FLUTTER_ROOT = Path(r"C:\Users\AnasDahou\flutter")
TIMEOUT_EXIT_CODE = 124


def configure_console_encoding() -> None:
    """Avoid Windows cp1252 crashes when Flutter prints Unicode diagnostics."""
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (OSError, ValueError):
            pass


def _split_path(value: str) -> list[str]:
    return [part for part in value.split(os.pathsep) if part]


def _dedupe_path_entries(entries: list[str]) -> list[str]:
    clean_entries: list[str] = []
    seen: set[str] = set()
    for entry in entries:
        key = entry.rstrip("\\/").lower()
        if key in seen:
            continue
        seen.add(key)
        clean_entries.append(entry)
    return clean_entries


def build_clean_env() -> dict[str, str]:
    env: dict[str, str] = {}
    path_entries: list[str] = []

    for key, value in os.environ.items():
        if key.lower() == "path":
            path_entries.extend(_split_path(value))
            continue
        env[key] = value

    flutter_root = Path(
        env.get("FLUTTER_ROOT")
        or os.environ.get("FLUTTER_ROOT")
        or str(DEFAULT_FLUTTER_ROOT)
    )
    flutter_bin = flutter_root / "bin"
    dart_bin = flutter_root / "bin" / "cache" / "dart-sdk" / "bin"

    path_entries = _dedupe_path_entries(
        [str(flutter_bin), str(dart_bin), *path_entries]
    )
    env["Path"] = os.pathsep.join(path_entries)
    env["FLUTTER_ROOT"] = str(flutter_root)

    # Keep these commands non-interactive and avoid telemetry files in AppData.
    env["CI"] = "true"
    env["NO_COLOR"] = "1"
    env["DART_SUPPRESS_ANALYTICS"] = "true"
    env["FLUTTER_SUPPRESS_ANALYTICS"] = "true"

    return env


def resolve_executable(command: str, env: dict[str, str]) -> str:
    flutter_root = Path(env["FLUTTER_ROOT"])
    if command == "dart":
        candidate = flutter_root / "bin" / "cache" / "dart-sdk" / "bin" / "dart.exe"
    elif command == "flutter":
        candidate = flutter_root / "bin" / "flutter.bat"
    else:
        raise ValueError(f"Unsupported command: {command}")

    if candidate.exists():
        return str(candidate)

    fallback = shutil.which(command, path=env.get("Path"))
    if fallback:
        return fallback

    raise FileNotFoundError(
        f"Cannot find {command}. Expected {candidate}, and it is not on Path."
    )


def kill_process_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return

    try:
        os.kill(pid, 9)
    except OSError:
        pass


def run_command(command: str, args: list[str], cwd: str | None, timeout: float) -> int:
    env = build_clean_env()
    executable = resolve_executable(command, env)
    resolved_cwd = Path(cwd).resolve() if cwd else Path.cwd()
    cmd = [executable, *args]

    start = time.perf_counter()
    print(f"[codex-dart-flutter] cwd: {resolved_cwd}", file=sys.stderr)
    print(
        f"[codex-dart-flutter] command: {command} {' '.join(args)}",
        file=sys.stderr,
    )

    proc = subprocess.Popen(
        cmd,
        cwd=str(resolved_cwd),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        elapsed = time.perf_counter() - start
        if stdout:
            print(stdout, end="")
        if stderr:
            print(stderr, end="", file=sys.stderr)
        print(
            f"[codex-dart-flutter] exit={proc.returncode} elapsed={elapsed:.2f}s",
            file=sys.stderr,
        )
        return int(proc.returncode or 0)
    except subprocess.TimeoutExpired:
        kill_process_tree(proc.pid)
        elapsed = time.perf_counter() - start
        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            stdout, stderr = "", ""

        if stdout:
            print(stdout, end="")
        if stderr:
            print(stderr, end="", file=sys.stderr)
        print(
            f"[codex-dart-flutter] timeout after {elapsed:.2f}s; process tree killed",
            file=sys.stderr,
        )
        return TIMEOUT_EXIT_CODE


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Safe Codex runner for Dart and Flutter commands."
    )
    parser.add_argument("--cwd", help="Working directory for the command.")
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="Timeout in seconds before killing the command tree.",
    )
    parser.add_argument("command", choices=("dart", "flutter"))
    parser.add_argument("args", nargs=argparse.REMAINDER)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    configure_console_encoding()
    args = parse_args(argv)
    return run_command(args.command, args.args, args.cwd, args.timeout)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
