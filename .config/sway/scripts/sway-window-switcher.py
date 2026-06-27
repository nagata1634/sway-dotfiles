#!/usr/bin/env python3
"""現在フォーカス中のワークスペース内のウィンドウを選んでフォーカスする。

ランチャーは fuzzel を優先（Wayland ネイティブ＝日本語入力でタイトル検索できる）。
fuzzel が無い場合は rofi にフォールバックする。
"""
import json
import shutil
import subprocess
import sys


def pick(menu: str, prompt: str):
    """改行区切りの候補から選択させ、選ばれた行の 0始まり index を返す（未選択は None）。"""
    if shutil.which("fuzzel"):
        cmd = ["fuzzel", "--dmenu", "--index", "--prompt", prompt + " "]
    else:
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-format", "i"]
    p = subprocess.run(cmd, input=menu, capture_output=True, text=True)
    idx = p.stdout.strip()
    return int(idx) if idx != "" else None


def focused_ws(node):
    if node.get("type") == "workspace":
        if '"focused":true' in json.dumps(node, separators=(",", ":")):
            return node
    for c in node.get("nodes", []) + node.get("floating_nodes", []):
        r = focused_ws(c)
        if r:
            return r
    return None


def walk(node, items):
    app = node.get("app_id") or (node.get("window_properties") or {}).get("class")
    is_leaf = not (node.get("nodes") or node.get("floating_nodes"))
    if app and is_leaf:
        items.append((node["id"], "%s: %s" % (app, node.get("name") or "")))
    for c in node.get("nodes", []) + node.get("floating_nodes", []):
        walk(c, items)


def main():
    tree = json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree"]))
    ws = focused_ws(tree)
    items = []
    if ws:
        walk(ws, items)
    if not items:
        return
    menu = "\n".join(label for _, label in items)
    idx = pick(menu, "Window")
    if idx is None:
        return
    con_id = items[idx][0]
    subprocess.run(["swaymsg", "[con_id=%d]" % con_id, "focus"])


if __name__ == "__main__":
    main()
