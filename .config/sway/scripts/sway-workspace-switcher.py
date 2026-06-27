#!/usr/bin/env python3
"""ワークスペース一覧をrofiで選んで切り替える。一覧にない名前を入力すれば新規作成。"""
import json
import subprocess
import sys


def main():
    wss = json.loads(subprocess.check_output(["swaymsg", "-t", "get_workspaces"]))
    names = [w["name"] for w in wss]
    menu = "\n".join(names)
    p = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", "Workspace"],
        input=menu, capture_output=True, text=True,
    )
    sel = p.stdout.strip()
    if sel == "":
        return
    subprocess.run(["swaymsg", "workspace", sel])


if __name__ == "__main__":
    main()
