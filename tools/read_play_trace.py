"""마이펫 테스트판 놀이 기록을 읽는다. python tools/read_play_trace.py --help"""

import argparse
from bisect import bisect_left, bisect_right
from collections import defaultdict
from io import TextIOWrapper
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys


DEVICE_DIR = "/sdcard/Android/data/com.aglioeolio.mypet.portfolio/files/mypet-qa"
ACTIONS = {
    "open": "놀아주기", "close": "그만 놀기", "trick": "개인기",
    "throwBall": "공 던지기", "treat": "간식", "notebook": "훈련 수첩",
}
TRICKS = {
    "sit": "앉아", "come": "이리 와", "down": "엎드려", "wait": "기다려",
    "spin": "돌아", "jump": "점프", "fetch": "물어와", "name": "이름", "potty": "배변",
}
OUTCOMES = {
    "away": "집 밖", "tired": "피곤해서 쉬기", "missed": "실패",
    "succeeded": "성공", "learned": "처음 배움",
}
EVENTS = {
    "wake": "앱 복귀", "pause": "앱 일시정지", "walk_start": "산책 시작",
    "walk_end": "산책 종료", "walk_refused": "산책 거절", "place_enter": "방문",
    "place_leave": "귀가", "notebook_open": "수첩 열림", "treat": "간식 주기",
    "ball_out": "공 꺼냄", "fetch": "공 가져옴", "throw": "공 던짐",
}
PHASES = {"pointer", "tap", "cancel", "result", "frame", "error"}
MENU = {"true": "열림", "false": "닫힘"}
COUNTS = {"attempts": "시도", "successes": "성공", "stars": "별"}


def read_device(serial):
    adb = shutil.which("adb")
    if not adb:
        for root in ("ANDROID_HOME", "ANDROID_SDK_ROOT", "LOCALAPPDATA"):
            if root not in os.environ:
                continue
            path = Path(os.environ[root])
            if root == "LOCALAPPDATA":
                path = path / "Android" / "sdk"
            candidate = path / "platform-tools" / ("adb.exe" if os.name == "nt" else "adb")
            if candidate.is_file():
                adb = str(candidate)
                break
    if not adb:
        raise ValueError("ADB를 찾지 못했습니다. Android SDK의 platform-tools 경로를 확인하세요.")

    def run(*args):
        return subprocess.run(
            [adb, "-s", serial, *args], capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=15, check=False,
        )

    state = run("get-state")
    if state.returncode or state.stdout.strip() != "device":
        raise ValueError("해당 기기에 접근할 수 없습니다. adb devices -l에서 연결과 승인을 확인하세요.")
    for name in ("play.previous.log", "play.log"):
        reply = run("shell", "cat", f"{DEVICE_DIR}/{name}")
        if reply.returncode:
            if "No such file or directory" in (reply.stderr + reply.stdout):
                continue
            raise ValueError("기기에서 놀이 기록을 읽을 수 없습니다. ADB 연결과 파일 접근 권한을 확인하세요.")
        yield from reply.stdout.splitlines()


def read_files(paths):
    for path in paths:
        with path.open("rb") as source:
            # Windows PowerShell의 리디렉션은 UTF-16 BOM을 붙이기도 한다.
            prefix = source.peek(2)[:2]
            encoding = "utf-16" if prefix in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
            with TextIOWrapper(source, encoding=encoding, errors="replace") as decoded:
                yield from decoded


def number(value):
    return value is not None and re.fullmatch(r"[0-9]{1,20}", value) is not None


def parse(lines):
    sessions = defaultdict(dict)
    for line in lines:
        _, marker, payload = line.partition("MypetQA ")
        if not marker:
            continue
        fields = dict(token.split("=", 1) for token in payload.split() if "=" in token)
        if number(fields.get("session")) and number(fields.get("seq")):
            sessions[int(fields["session"])][int(fields["seq"])] = fields
    return sessions


def event_label(row):
    event = row.get("event")
    if event == "tab":
        return {"home": "집 탭", "diary": "일기 탭", "collection": "도감 탭"}.get(row.get("to"))
    if event == "tap":
        return {"pet": "쓰다듬기", "feed": "밥 주기"}.get(row.get("what"))
    if event == "ball_away":
        return {"true": "공 자동 정리", "false": "공 정리"}.get(row.get("auto"))
    return EVENTS.get(event)


def describe(phases, changes, gaps_after):
    result = phases.get("result", {})
    frame = phases.get("frame", {})
    if "cancel" in phases and "tap" not in phases:
        return "입력 취소"
    parts = ["탭 접수" if "tap" in phases else "탭 접수 기록 없음"]
    if "error" in phases:
        parts.append("처리 중 오류")
    if not result and "tap" in phases and "error" not in phases:
        parts.append("판정 기록 없음")
    if outcome := OUTCOMES.get(result.get("outcome")):
        parts.append(outcome)
    if result.get("action") in {"open", "close"} and result.get("menu_open") in MENU:
        parts.append("처리 직후 " + MENU[result["menu_open"]])
    for key, title in COUNTS.items():
        value = result.get(key)
        if number(value):
            parts.append(f"{title} {value}")
    if frame:
        if frame.get("menu_open") in MENU:
            parts.append("화면 " + MENU[frame["menu_open"]])
    elif result:
        parts.append("화면 기록 없음")
    if result and frame:
        changed = []
        for key, label in {"menu_open": "놀이판", **COUNTS}.items():
            a, b = result.get(key), frame.get(key)
            if key == "menu_open":
                a, b = MENU.get(a), MENU.get(b)
            elif not number(a) or not number(b):
                continue
            if a is not None and b is not None and a != b:
                changed.append(f"{label} {a}→{b}")
        if changed:
            start, end = int(result["seq"]), int(frame["seq"])
            if bisect_left(gaps_after, start) != bisect_left(gaps_after, end):
                parts.append("중간 기록 누락 · 직접 비교 보류")
            elif bisect_right(changes, start) != bisect_left(changes, end):
                parts.append("사이 동작 있음 · 직접 비교 보류")
            else:
                parts.append("판정·화면 불일치(" + ", ".join(changed) + ")")
    return " · ".join(parts)


def session_rows(records):
    inputs = {}
    changes = []
    notices = []
    previous = None
    ordered = sorted(records)
    gaps_after = [a for a, b in zip(ordered, ordered[1:]) if b != a + 1]
    for seq in ordered:
        row = records[seq]
        event = event_label(row)
        if event:
            changes.append(seq)
            previous = event
            continue
        if row.get("event") in {"flutter_error", "unhandled_error"}:
            detail = "Flutter 오류" if row["event"] == "flutter_error" else "처리되지 않은 오류"
            if row.get("kind") in {"state", "range", "type", "argument", "file", "flutter", "other"}:
                detail += " · " + row["kind"]
            if re.fullmatch(r"[a-zA-Z0-9_/]+\.dart:\d+", row.get("origin", "")):
                detail += " · " + row["origin"]
            notices.append((seq, detail))
            continue
        if row.get("phase") not in PHASES or row.get("action") not in ACTIONS or not number(row.get("input")):
            continue
        action = TRICKS.get(row.get("trick"), ACTIONS[row["action"]])
        input_id = int(row["input"])
        _, _, _, phases = inputs.setdefault(input_id, (seq, action, previous, {}))
        phases[row["phase"]] = row
        if row["phase"] == "tap":
            changes.append(seq)
            previous = action
    for input_id, (seq, action, prior, phases) in inputs.items():
        last_action = f"직전 {prior} → " if prior else ""
        notes = describe(phases, changes, gaps_after)
        notices.append((seq, f"#{input_id} {last_action}{action} | {notes}"))
    rows = []
    for seq, message in sorted(notices):
        stamp = re.fullmatch(r"\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2})(?:\.\d+)?Z", records[seq].get("time", ""))
        rows.append((stamp[1] + " UTC  " if stamp else "") + message)
    return rows


def main():
    parser = argparse.ArgumentParser(description="기기 또는 보관 파일에서 마이펫 놀이 입력·판정·화면을 시간순으로 확인합니다.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--serial", help="adb devices -l에 표시된 테스트폰 ID")
    source.add_argument("--file", type=Path, action="append", help="QA 기록 파일. 여러 번 지정할 수 있습니다.")
    parser.add_argument("--last", type=int, metavar="N", help="마지막 N개 입력·오류만 표시")
    args = parser.parse_args()
    if args.last is not None and args.last <= 0:
        parser.error("--last 값은 1 이상이어야 합니다.")
    try:
        sessions = parse(read_device(args.serial) if args.serial else read_files(args.file))
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"놀이 기록 읽기 실패. {exc}", file=sys.stderr)
        return 1
    if not sessions:
        print("놀이 QA 기록이 없습니다. 기록 기능이 포함된 테스트판인지, 설정의 사용 기록이 켜져 있는지 확인하세요.", file=sys.stderr)
        return 1
    rows = [(session, row) for session in sorted(sessions) for row in session_rows(sessions[session])]
    if args.last:
        rows = rows[-args.last:]
    previous = None
    for session, row in rows:
        if session != previous:
            build = sessions[session].get(1, {}).get("build", "")
            label = f" · 빌드 {build}" if re.fullmatch(r"[a-zA-Z0-9_.-]{1,24}", build) else ""
            print(f"세션 {session}{label}")
            previous = session
        print(row)
    if not rows:
        print("세션은 기록됐습니다. 보관 구간에 놀이 입력이 없습니다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
