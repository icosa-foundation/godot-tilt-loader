#!/usr/bin/env python3
"""Run the exported Web probe through ChromeDriver without Python dependencies."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path


def request_json(
    method: str,
    url: str,
    payload: dict[str, object] | None = None,
) -> dict[str, object]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed ({error.code}): {body}") from error


def wait_for_driver(base_url: str, process: subprocess.Popen[bytes]) -> None:
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"ChromeDriver exited with code {process.returncode}")
        try:
            request_json("GET", f"{base_url}/status")
            return
        except (OSError, RuntimeError):
            time.sleep(0.2)
    raise TimeoutError("ChromeDriver did not become ready")


def session_id_from(response: dict[str, object]) -> str:
    value = response.get("value")
    if isinstance(value, dict) and isinstance(value.get("sessionId"), str):
        return value["sessionId"]
    if isinstance(response.get("sessionId"), str):
        return response["sessionId"]
    raise RuntimeError(f"ChromeDriver did not return a session ID: {response}")


def write_diagnostics(
    base_url: str,
    session_id: str,
    dom_path: Path,
    browser_log_path: Path,
) -> None:
    try:
        source_response = request_json(
            "GET",
            f"{base_url}/session/{session_id}/source",
        )
        source = source_response.get("value", "")
        dom_path.write_text(str(source), encoding="utf-8")
    except Exception as error:  # Diagnostics must not mask the probe result.
        dom_path.write_text(f"OBH_WEB_CI: unable to capture DOM: {error}\n", encoding="utf-8")

    try:
        logs_response = request_json(
            "POST",
            f"{base_url}/session/{session_id}/log",
            {"type": "browser"},
        )
        entries = logs_response.get("value", [])
        browser_log_path.write_text(
            "\n".join(json.dumps(entry, sort_keys=True) for entry in entries) + "\n",
            encoding="utf-8",
        )
    except Exception as error:  # Diagnostics must not mask the probe result.
        browser_log_path.write_text(
            f"OBH_WEB_CI: unable to capture browser logs: {error}\n",
            encoding="utf-8",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--chrome-binary", required=True)
    parser.add_argument("--timeout", type=float, default=60)
    parser.add_argument("--dom-log", type=Path, default=Path("web-dom.log"))
    parser.add_argument(
        "--browser-log",
        type=Path,
        default=Path("web-browser.log"),
    )
    parser.add_argument(
        "--driver-log",
        type=Path,
        default=Path("chromedriver.log"),
    )
    args = parser.parse_args()

    driver = shutil.which("chromedriver")
    if driver is None:
        raise RuntimeError("chromedriver is not available on PATH")

    base_url = "http://127.0.0.1:9515"
    session_id: str | None = None
    result = ""
    with args.driver_log.open("wb") as driver_log:
        process = subprocess.Popen(
            [driver, "--port=9515"],
            stdout=driver_log,
            stderr=subprocess.STDOUT,
        )
        try:
            wait_for_driver(base_url, process)
            session_response = request_json(
                "POST",
                f"{base_url}/session",
                {
                    "capabilities": {
                        "alwaysMatch": {
                            "browserName": "chrome",
                            "goog:chromeOptions": {
                                "binary": args.chrome_binary,
                                "args": [
                                    "--headless=new",
                                    "--no-sandbox",
                                    "--enable-unsafe-swiftshader",
                                    "--use-angle=swiftshader",
                                ],
                            },
                            "goog:loggingPrefs": {"browser": "ALL"},
                        }
                    }
                },
            )
            session_id = session_id_from(session_response)
            session_url = f"{base_url}/session/{session_id}"
            request_json("POST", f"{session_url}/url", {"url": args.url})

            deadline = time.monotonic() + args.timeout
            while time.monotonic() < deadline:
                response = request_json(
                    "POST",
                    f"{session_url}/execute/sync",
                    {
                        "script": (
                            "return document.documentElement"
                            ".getAttribute('data-obh-native');"
                        ),
                        "args": [],
                    },
                )
                value = response.get("value")
                if value in ("true", "false"):
                    result = str(value)
                    break
                time.sleep(0.5)

            write_diagnostics(
                base_url,
                session_id,
                args.dom_log,
                args.browser_log,
            )
        finally:
            if session_id is not None:
                try:
                    request_json(
                        "DELETE",
                        f"{base_url}/session/{session_id}",
                    )
                except Exception:
                    pass
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

    if result != "true":
        print(
            f"OBH_WEB_CI: expected data-obh-native=true, got {result or 'timeout'}",
        )
        return 1
    print("OBH_WEB_CI: data-obh-native=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
