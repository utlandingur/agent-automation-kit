#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import time
from typing import Optional


def _write_log(log_file: str, message: str) -> None:
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"[agent-supervisor] {timestamp} {message}\n")


def _has_last_message(last_file: str) -> bool:
    return os.path.exists(last_file) and os.path.getsize(last_file) > 0


def _notify_orchestrator(
    args: argparse.Namespace,
    event: str,
    attempt: int,
    rc: int,
    runtime: float,
    has_last: bool,
) -> None:
    if not args.notify_script:
        return
    if not os.path.exists(args.notify_script):
        return
    payload = [
        args.notify_script,
        "--event",
        event,
        "--run-name",
        args.run_name,
        "--attempt",
        str(attempt),
        "--exit-code",
        str(rc),
        "--runtime-seconds",
        f"{runtime:.1f}",
        "--has-last-message",
        "yes" if has_last else "no",
        "--pid-file",
        args.pid_file,
        "--log-file",
        args.log_file,
        "--last-file",
        args.last_file,
    ]
    try:
        subprocess.run(
            payload,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            cwd=args.workdir,
        )
    except Exception:
        # Notification hook must never crash supervisor flow.
        return


def _daemonize_with_pid_pipe() -> int:
    read_fd, write_fd = os.pipe()

    pid = os.fork()
    if pid > 0:
        os.close(write_fd)
        daemon_pid = os.read(read_fd, 64).decode("utf-8").strip()
        os.close(read_fd)
        if not daemon_pid:
            print("Failed to get daemon pid", file=sys.stderr)
            sys.exit(1)
        print(daemon_pid)
        sys.exit(0)

    os.setsid()
    pid = os.fork()
    if pid > 0:
        os._exit(0)

    os.close(read_fd)
    os.write(write_fd, str(os.getpid()).encode("utf-8"))
    os.close(write_fd)

    devnull_fd = os.open(os.devnull, os.O_RDWR)
    os.dup2(devnull_fd, 0)
    os.dup2(devnull_fd, 1)
    os.dup2(devnull_fd, 2)
    os.close(devnull_fd)
    return os.getpid()


def _run_supervised(args: argparse.Namespace, supervisor_pid: int) -> int:
    with open(args.pid_file, "w", encoding="utf-8") as f:
        f.write(str(supervisor_pid))

    max_attempts = args.max_restarts + 1
    for attempt in range(1, max_attempts + 1):
        start = time.time()
        _write_log(args.log_file, f"launch attempt {attempt}/{max_attempts}")
        cmd = [
            "codex",
            "exec",
            "--model",
            args.model,
            "-c",
            f"model_reasoning_effort={args.reasoning_effort}",
            "-c",
            f"model_reasoning_summary={args.reasoning_summary}",
            "--cd",
            args.workdir,
            "--output-last-message",
            args.last_file,
            "--json",
            "-",
        ]
        if args.exec_mode == "full_auto":
            cmd.insert(2, "--full-auto")

        with open(args.prompt_file, "rb") as in_f, open(args.log_file, "ab", buffering=0) as out_f:
            proc = subprocess.Popen(
                cmd,
                stdin=in_f,
                stdout=out_f,
                stderr=subprocess.STDOUT,
                cwd=args.workdir,
                start_new_session=True,
                close_fds=True,
            )
            rc = proc.wait()

        runtime = time.time() - start
        has_last = _has_last_message(args.last_file)
        _write_log(args.log_file, f"attempt {attempt} exit rc={rc} runtime={runtime:.1f}s last_message={has_last}")
        _notify_orchestrator(args, "attempt_exit", attempt, rc, runtime, has_last)

        if rc == 0 and has_last:
            _notify_orchestrator(args, "run_completed", attempt, rc, runtime, has_last)
            return 0

        should_retry = attempt < max_attempts and (runtime < args.min_runtime_seconds or not has_last or rc != 0)
        if should_retry:
            time.sleep(args.retry_delay_seconds)
            continue
        break

    if not _has_last_message(args.last_file):
        with open(args.last_file, "w", encoding="utf-8") as f:
            f.write(
                "Agent stopped unexpectedly before completion. "
                "Check the run log and relaunch if needed."
            )
    _notify_orchestrator(args, "run_stopped", max_attempts, 1, 0.0, _has_last_message(args.last_file))
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Launch detached supervisor for codex agent runs.")
    parser.add_argument("--workdir", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--log-file", required=True)
    parser.add_argument("--last-file", required=True)
    parser.add_argument("--pid-file", required=True)
    parser.add_argument("--run-name", required=True)
    parser.add_argument("--notify-script", default="")
    parser.add_argument(
        "--exec-mode",
        default="guarded",
        choices=["guarded", "full_auto"],
        help="guarded omits --full-auto; full_auto enables it explicitly",
    )
    parser.add_argument(
        "--reasoning-effort",
        default="low",
        choices=["minimal", "low", "medium", "high"],
    )
    parser.add_argument(
        "--reasoning-summary",
        default="concise",
        choices=["concise", "detailed", "auto"],
    )
    parser.add_argument("--max-restarts", type=int, default=2)
    parser.add_argument("--min-runtime-seconds", type=int, default=20)
    parser.add_argument("--retry-delay-seconds", type=int, default=2)
    args = parser.parse_args()

    supervisor_pid = _daemonize_with_pid_pipe()
    return _run_supervised(args, supervisor_pid)


if __name__ == "__main__":
    sys.exit(main())
