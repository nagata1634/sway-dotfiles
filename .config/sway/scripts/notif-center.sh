#!/usr/bin/env bash
# Rofi 通知センター（Catppuccin 統一テーマ）。
# dunst の履歴を一覧表示し、選ぶと再表示。おやすみモード切替・全消去も。
# Mod+Shift+n、または Waybar のベルアイコンから起動。
set -uo pipefail

THEME="$HOME/.config/rofi/config.rasi"
menu() { rofi -dmenu -i -theme "$THEME" -no-custom "$@"; }

paused=$(dunstctl is-paused 2>/dev/null)
dnd="󰂚  おやすみモードを切替（現在: 通常）"
[ "$paused" = "true" ] && dnd="󰂜  おやすみモードを切替（現在: 停止中）"

# 履歴を "id<US>表示文字列" 形式で取得（<US>=0x1f）
mapfile -t entries < <(dunstctl history 2>/dev/null | python3 -c '
import sys, json
d = json.load(sys.stdin)
try: up = float(open("/proc/uptime").read().split()[0])
except Exception: up = None
def age(ts_us):
    if up is None or not ts_us: return ""
    s = up - ts_us/1e6
    if s < 0: return ""
    if s < 60:    return "%d秒前"  % s
    if s < 3600:  return "%d分前"  % (s//60)
    if s < 86400: return "%d時間前"% (s//3600)
    return "%d日前" % (s//86400)
icons = {"low":"󰋽", "normal":"󰂚", "critical":"󰀦"}
data = d.get("data", [])
notes = data[0] if data else []
for n in notes:
    g = lambda k: (n.get(k) or {}).get("data")
    icon = icons.get(g("urgency"), "󰂚")
    app  = (g("appname") or "").strip()
    summ = (g("summary") or "").replace("\n", " ")
    body = (g("body") or "").replace("\n", " ")
    parts = [icon]
    if app:  parts.append("["+app+"]")
    if summ: parts.append(summ)
    if body: parts.append("— "+body)
    label = " ".join(parts)
    if len(label) > 95: label = label[:94] + "…"
    a = age(g("timestamp") or 0)
    if a: label += "  (" + a + ")"
    print("%s\x1f%s" % (g("id"), label))
')

ids=() lines=()
for e in "${entries[@]}"; do ids+=("${e%%$'\x1f'*}"); lines+=("${e#*$'\x1f'}"); done
count=${#lines[@]}

if [ "$count" -eq 0 ]; then
  list="󰂜  （通知はありません）"
else
  list=$(printf '%s\n' "${lines[@]}")
fi

choice=$(printf '%s\n%s\n󰎟  すべてクリア\n󰑐  最新を再表示' "$list" "$dnd" \
  | menu -p "通知センター ($count)")
[ -z "$choice" ] && exit 0

case "$choice" in
  *おやすみモード*)   dunstctl set-paused toggle ;;
  *すべてクリア*)     dunstctl history-clear ;;
  *最新を再表示*)     dunstctl history-pop ;;
  *通知はありません*) : ;;
  *) for i in "${!lines[@]}"; do
       [ "${lines[$i]}" = "$choice" ] && { dunstctl history-pop "${ids[$i]}"; break; }
     done ;;
esac
