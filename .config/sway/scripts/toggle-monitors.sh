#!/usr/bin/env bash
# DP-5 と DP-6 の役割（横/左 ⇄ 縦/右）を入れ替えるトグル。
#
# この2台は同一型番・EDIDシリアル無しでソフトから区別できず、
# 起動時に DP番号と物理モニターの対応が入れ替わることがある。
# 配置がズレたらキー一発でこのスクリプトを実行して正しい配置に直す。
set -euo pipefail

BG_DIR="$HOME/Pictures/background/.span"

# 横モニター（左）として設定
apply_h() {
  swaymsg "output $1 mode 2560x1440 position 0 967 transform normal bg $BG_DIR/dp6.png fill"
}
# 縦モニター（右・反時計回り90度=transform 270）として設定
apply_v() {
  swaymsg "output $1 mode 2560x1440 position 2560 0 transform 270 bg $BG_DIR/dp5.png fill"
}

# 現在の DP-5 の向きを取得（normal なら DP-5 が横/左 = 入れ替える必要あり）
t5=$(swaymsg -t get_outputs | python3 -c \
  'import sys,json; o=[x for x in json.load(sys.stdin) if x["name"]=="DP-5"]; print(o[0]["transform"] if o else "")')

if [ "$t5" = "normal" ]; then
  # 今: DP-5=横/左, DP-6=縦/右 → 反転
  apply_v DP-5
  apply_h DP-6
else
  # 今: DP-5=縦/右（など）→ DP-5=横/左 に
  apply_h DP-5
  apply_v DP-6
fi
