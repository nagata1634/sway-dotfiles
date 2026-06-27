#!/usr/bin/env bash
# Rofi 電源メニュー（Catppuccin 統一テーマ）。
# Waybar の電源アイコンクリック、または $mod+x から起動。
#
# 破壊的な操作（再起動/シャットダウン/更新/ログアウト/BIOS）は
# 「はい/いいえ」確認をはさむ。更新系は端末を開いて進捗を表示する。
set -euo pipefail

THEME="$HOME/.config/rofi/config.rasi"
# ユーザーの端末（sway config の $term と同じ wezterm ラッパー）でコマンド実行。
# term.sh が RPM 版 wezterm 優先・未導入なら Flatpak 版にフォールバック。
TERM_RUN=("$HOME/.config/sway/scripts/term.sh" start --)

# swaylock（Catppuccin Mocha 配色）
lock() {
  swaylock \
    --color 1e1e2e \
    --inside-color 313244 --ring-color 89b4fa \
    --key-hl-color cba6f7 --bs-hl-color f38ba8 --line-color 00000000 \
    --separator-color 00000000 --text-color cdd6f4 \
    --indicator-radius 90 --indicator-thickness 8 \
    --inside-clear-color fab387 --ring-clear-color fab387 \
    --inside-ver-color 89b4fa --ring-ver-color 89b4fa \
    --inside-wrong-color f38ba8 --ring-wrong-color f38ba8
}

# 端末で実行して進捗を見せる（更新系）
run_in_term() { "${TERM_RUN[@]}" bash -lc "$1"; }

# 現在 boot している ostree の origin ref を返す（例: fedora:fedora/44/x86_64/sericea）
booted_origin() {
  rpm-ostree status --booted --json 2>/dev/null \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["deployments"][0]["origin"])'
}

# 確認ダイアログ。「はい」を選んだときだけ成功(0)を返す。
confirm() {
  local ans
  ans=$(printf '%s\0meta\x1f%s\n' 'いいえ' 'no iie cancel' 'はい' 'yes hai ok' \
    | rofi -dmenu -i -theme "$THEME" -p "$1" -no-custom -lines 2)
  [ "$ans" = "はい" ]
}

# 各行 = 「表示ラベル」+「meta(画面に出ない英字キーワード)」。
# rofi の dmenu 行オプション形式: <表示>\0meta\x1f<検索語>
# → 日本語が打てなくても英字/ローマ字で絞り込める（選択時の戻り値は表示ラベル）。
emit_rows() {
  printf '%s\0meta\x1f%s\n' \
    "󰌾  ロック"                       "lock screen rokku" \
    "󰒲  サスペンド"                   "suspend sleep sasupendo" \
    "󰍃  ログアウト"                   "logout exit logoff roguauto" \
    "󰜉  再起動"                       "reboot restart saikidou" \
    "󰐥  シャットダウン"               "shutdown poweroff shutdown shatto" \
    "󰚰  OS更新して再起動"             "os update upgrade koushin" \
    "󰏖  フル更新して再起動"           "full update upgrade flatpak furu koushin" \
    "󰬬  次バージョンへアップグレード" "rebase next version upgrade tsugi version" \
    "󰒓  BIOS設定で再起動"             "bios firmware setup uefi"
}

choice=$(emit_rows | rofi -dmenu -i -theme "$THEME" -p "電源" -no-custom)
[ -z "$choice" ] && exit 0

case "$choice" in
  *ロック*)         lock ;;
  *サスペンド*)     systemctl suspend ;;
  *ログアウト*)     confirm "ログアウトしますか？"     && swaymsg exit ;;
  *シャットダウン*) confirm "シャットダウンしますか？" && systemctl poweroff ;;
  *BIOS*)           confirm "BIOS設定で再起動しますか？" \
                      && systemctl reboot --firmware-setup ;;
  *OS更新*)         confirm "OSを更新して再起動しますか？" \
                      && run_in_term "rpm-ostree upgrade && systemctl reboot" ;;
  *フル更新*)       confirm "OSとアプリを更新して再起動しますか？" \
                      && run_in_term "rpm-ostree upgrade; flatpak update -y; systemctl reboot" ;;
  *次バージョン*)
    # 現在 boot している ref を分解し、remote の安定版ベース ref から
    # 「現在より新しい最小バージョン」を次版として選ぶ。
    #
    # variant 名(sericea 等)はハードコードしない。過去に sway→sericea の rename が
    # あったため、再度 rename(例: sericea→sway-atomic)されても追従できるよう、
    # variant 候補を複数持って remote に実在する方を採用する:
    #   1) 現在の ref の variant（最優先＝なるべく同じ系統を維持）
    #   2) /etc/os-release の VARIANT_ID（rename 後の新名称になりやすい）
    #   3) 下の EXTRA_VARIANTS（将来の改名に手動で備える保険）
    EXTRA_VARIANTS=()   # 例: ('sway-atomic')。必要になったら追記。
    origin=$(booted_origin) || origin=""
    remote=${origin%%:*}                                                  # 例: fedora
    ver=$(printf '%s' "$origin"  | sed -nE 's#.*/([0-9]+)/[^/]+/[^/]+$#\1#p')
    arch=$(printf '%s' "$origin" | sed -nE 's#.*/[0-9]+/([^/]+)/[^/]+$#\1#p')
    cur_variant=$(printf '%s' "$origin" | sed -nE 's#.*/([^/]+)$#\1#p')
    variant_id=$( . /etc/os-release 2>/dev/null; printf '%s' "${VARIANT_ID:-}" )
    if [ -z "$origin" ] || [ -z "$ver" ] || [ -z "$arch" ] || [ -z "$cur_variant" ]; then
      notify-send "OSアップグレード" "現在の ref を判別できませんでした（$origin）。"
      exit 1
    fi
    # variant 候補（優先順・重複除去・空除去）
    mapfile -t cands < <(printf '%s\n' "$cur_variant" "$variant_id" "${EXTRA_VARIANTS[@]}" \
                          | awk 'NF && !seen[$0]++')
    alt=$(IFS='|'; printf '%s' "${cands[*]}")                             # 例: sericea|sway-atomic

    notify-send "OSアップグレード" "新しいバージョンを確認しています…"
    # updates/testing/rawhide を除くベース ref のみを「<ver> <variant>」で取得
    refs=$(timeout 25 ostree remote refs "$remote" 2>/dev/null \
            | sed -nE "s#^${remote}:fedora/([0-9]+)/${arch}/(${alt})\$#\1 \2#p")
    # 現在より新しい最小バージョンを次版に
    next=$(printf '%s\n' "$refs" | awk -v c="$ver" '$1 > c {print $1}' | sort -n | head -1)
    if [ -z "$next" ]; then
      notify-send "OSアップグレード" "$ver より新しいバージョンはまだ提供されていません。"
      exit 0
    fi
    # その版で実在する variant を優先順に採用（rename 検知）
    chosen_variant=""
    for c in "${cands[@]}"; do
      if printf '%s\n' "$refs" | grep -qx "$next $c"; then chosen_variant=$c; break; fi
    done
    next_ref="${remote}:fedora/${next}/${arch}/${chosen_variant}"
    msg="Fedora $ver → $next にアップグレード（rebase）して再起動しますか？"
    [ "$chosen_variant" != "$cur_variant" ] \
      && msg="$msg
※variant が $cur_variant → $chosen_variant に変わります"
    confirm "$msg
($next_ref)" \
      && run_in_term "rpm-ostree rebase $next_ref && systemctl reboot"
    ;;
  *再起動*)         confirm "再起動しますか？"         && systemctl reboot ;;
esac
