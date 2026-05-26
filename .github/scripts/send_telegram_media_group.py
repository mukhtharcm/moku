#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]
VERSION = os.environ["VERSION"]
BUILD_NUMBER = os.environ["BUILD_NUMBER"]
SHORT_SHA = os.environ["SHORT_SHA"]
RUN_URL = os.environ["RUN_URL"]

APK_PATHS = [
    ROOT / "dist/app-arm64-v8a-release.apk",
    ROOT / "dist/app-armeabi-v7a-release.apk",
    ROOT / "dist/app-x86_64-release.apk",
]


def curl_json(args: list[str]) -> dict:
    result = subprocess.run(
        ["curl", "--fail-with-body", "--silent", "--show-error", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        if result.stdout:
            print(result.stdout, file=sys.stderr)
        raise SystemExit(result.returncode)
    return json.loads(result.stdout)


def delete_message(message_id: int) -> None:
    payload = urllib.parse.urlencode({"chat_id": CHAT_ID, "message_id": message_id}).encode()
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{TOKEN}/deleteMessage",
        data=payload,
    )
    with urllib.request.urlopen(request) as response:
        body = json.loads(response.read().decode())
    if not body.get("ok"):
        raise RuntimeError(f"Failed to delete staging message {message_id}: {body}")


def stage_documents() -> list[dict]:
    staged = []
    try:
        for apk_path in APK_PATHS:
            if not apk_path.exists():
                raise FileNotFoundError(f"Missing APK for Telegram upload: {apk_path}")
            payload = curl_json(
                [
                    "-X",
                    "POST",
                    f"https://api.telegram.org/bot{TOKEN}/sendDocument",
                    "-F",
                    f"chat_id={CHAT_ID}",
                    "-F",
                    f"document=@{apk_path}",
                    "-F",
                    "caption=staging",
                ]
            )
            result = payload["result"]
            staged.append(
                {
                    "message_id": result["message_id"],
                    "file_id": result["document"]["file_id"],
                    "file_name": result["document"]["file_name"],
                }
            )
        return staged
    except Exception:
        for item in reversed(staged):
            try:
                delete_message(item["message_id"])
            except Exception:
                pass
        raise


def send_group(staged: list[dict]) -> dict:
    media = [
        {
            "type": "document",
            "media": staged[0]["file_id"],
        },
        {"type": "document", "media": staged[1]["file_id"]},
        {"type": "document", "media": staged[2]["file_id"]},
    ]
    return curl_json(
        [
            "-X",
            "POST",
            f"https://api.telegram.org/bot{TOKEN}/sendMediaGroup",
            "-F",
            f"chat_id={CHAT_ID}",
            "-F",
            f"media={json.dumps(media, separators=(',', ':'))}",
        ]
    )


def send_summary() -> dict:
    text = (
        "Moku Android canary\n"
        "Artifact set: split APKs\n"
        f"Version: {VERSION} ({BUILD_NUMBER})\n"
        f"Commit: {SHORT_SHA}\n"
        f"Run: {RUN_URL}"
    )
    return curl_json(
        [
            "-X",
            "POST",
            f"https://api.telegram.org/bot{TOKEN}/sendMessage",
            "-F",
            f"chat_id={CHAT_ID}",
            "-F",
            f"text={text}",
            "-F",
            "disable_web_page_preview=true",
        ]
    )


def main() -> None:
    staged = stage_documents()
    try:
        for item in staged:
            delete_message(item["message_id"])
        result = send_group(staged)
        summary = send_summary()
    except Exception:
        raise

    print(
        json.dumps(
            {
                "media_group_id": result["result"][0]["media_group_id"],
                "message_ids": [message["message_id"] for message in result["result"]],
                "files": [item["file_name"] for item in staged],
                "summary_message_id": summary["result"]["message_id"],
            }
        )
    )


if __name__ == "__main__":
    main()
