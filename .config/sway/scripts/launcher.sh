#!/usr/bin/env bash
# アプリランチャー（Super+d）。
# fuzzel(Wayland ネイティブ＝日本語入力でアプリ検索できる)があれば優先。
# まだ未導入(rpm-ostree でレイヤリング＆再起動する前)なら rofi にフォールバックし、
# ランチャーが使えない空白期間を作らない。再起動後は自動的に fuzzel に切り替わる。
set -euo pipefail

if command -v fuzzel >/dev/null 2>&1; then
  exec fuzzel
else
  exec rofi -terminal "$HOME/.config/sway/scripts/term.sh" -show drun -modes drun
fi
