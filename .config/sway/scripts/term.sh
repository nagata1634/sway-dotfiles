#!/usr/bin/env bash
# ターミナル起動ラッパー（Super+Return / power-menu の更新表示などで使用）。
# RPM(ネイティブ)版 wezterm があれば優先し、未導入(rpm-ostree レイヤリング前)なら
# Flatpak 版にフォールバックする。RPM へ移行後も無停止で切り替わる。
# 引数はそのまま渡す（例: term.sh start -- bash -lc "..."）。
if command -v wezterm >/dev/null 2>&1; then
  exec wezterm "$@"
else
  exec flatpak run org.wezfurlong.wezterm "$@"
fi
