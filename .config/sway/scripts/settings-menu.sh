#!/usr/bin/env bash
# Rofi 設定ハブ（Catppuccin 統一テーマ）。
# Mod+Ctrl+S で起動。ハブから各サブメニューへ降りる。
#   引数なし          → ハブ
#   引数(section名)   → 各サブメニュー（「戻る」で $0 を exec してハブへ）
set -uo pipefail

THEME="$HOME/.config/rofi/config.rasi"
SCRIPTS="$HOME/.config/sway/scripts"
BACK="󰌍  戻る"

menu() { rofi -dmenu -i -theme "$THEME" -no-custom "$@"; }
notify() { command -v notify-send >/dev/null && notify-send "設定" "$1" || true; }
home() { exec "$0"; }   # ハブへ戻る

# ---------- WiFi ----------
section_wifi() {
  if [ "$(nmcli -t -f WIFI radio 2>/dev/null)" = "disabled" ]; then
    case "$(printf '󰖩  WiFi を有効にする\n󰒓  詳細設定 (nm-connection-editor)\n%s' "$BACK" | menu -p "WiFi: オフ")" in
      *有効*) nmcli radio wifi on; notify "WiFi を有効化" ;;
      *詳細*) nm-connection-editor & ;;
      *戻る*) home ;;
    esac
    return
  fi

  sig() { local s=$1; if [ "$s" -ge 80 ]; then echo 󰤨; elif [ "$s" -ge 55 ]; then echo 󰤥; elif [ "$s" -ge 30 ]; then echo 󰤢; else echo 󰤟; fi; }
  local SEP=$'\x1f'
  mapfile -t rows < <(nmcli --terse --fields IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes | sed 's/\\:/'"$SEP"'/g')
  local ssids=() secs=() lines=()
  for row in "${rows[@]}"; do
    IFS=':' read -r inuse signal security ssid <<<"$row"
    ssid=${ssid//$SEP/:}; [ -z "$ssid" ] && continue
    local mark="  "; [ "$inuse" = "*" ] && mark="󰸞 "
    local lock="";  [ -n "$security" ] && [ "$security" != "--" ] && lock=" 󰌾"
    ssids+=("$ssid"); secs+=("$security")
    lines+=("$(sig "${signal:-0}") ${mark}${ssid}${lock}")
  done

  local choice
  choice=$(printf '%s\n󰑓  再スキャン\n󰖪  WiFi を無効にする\n󰒓  詳細設定 (nm-connection-editor)\n%s' \
    "$(printf '%s\n' "${lines[@]}")" "$BACK" | menu -p "WiFi 接続")
  [ -z "$choice" ] && return
  case "$choice" in
    *再スキャン*) exec "$0" wifi ;;
    *無効*)       nmcli radio wifi off; notify "WiFi を無効化"; return ;;
    *詳細設定*)   nm-connection-editor & return ;;
    "$BACK")      home ;;
  esac

  local target="" sec=""
  for i in "${!lines[@]}"; do [ "${lines[$i]}" = "$choice" ] && { target="${ssids[$i]}"; sec="${secs[$i]}"; break; }; done
  [ -z "$target" ] && return

  if nmcli -t -f NAME connection show | grep -Fxq "$target"; then
    nmcli connection up id "$target" && notify "$target に接続" || notify "$target 接続失敗"
  elif [ -n "$sec" ] && [ "$sec" != "--" ]; then
    local pw; pw=$(rofi -dmenu -password -theme "$THEME" -p "$target のパスワード" -lines 0)
    [ -z "$pw" ] && return
    nmcli device wifi connect "$target" password "$pw" && notify "$target に接続" || notify "$target 接続失敗（パスワード確認）"
  else
    nmcli device wifi connect "$target" && notify "$target に接続" || notify "$target 接続失敗"
  fi
}

# ---------- Bluetooth ----------
section_bt() {
  local powered; powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')
  local toggle="󰂲  Bluetooth を ON にする"; [ "$powered" = "yes" ] && toggle="󰂲  Bluetooth を OFF にする"

  local devlines=() macs=()
  if [ "$powered" = "yes" ]; then
    while read -r _ mac name; do
      [ -z "${mac:-}" ] && continue
      local m="  "; bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes" && m="󰸞 "
      macs+=("$mac"); devlines+=("󰂱 ${m}${name}")
    done < <(bluetoothctl devices Paired 2>/dev/null)
  fi

  local choice
  choice=$(printf '%s\n%s\n󰂯  詳細設定 (Blueman)\n%s' \
    "$toggle" "$(printf '%s\n' "${devlines[@]}")" "$BACK" | menu -p "Bluetooth")
  [ -z "$choice" ] && return
  case "$choice" in
    *ON*)   bluetoothctl power on;  notify "Bluetooth ON"; exec "$0" bt ;;
    *OFF*)  bluetoothctl power off; notify "Bluetooth OFF"; return ;;
    *Blueman*) blueman-manager & return ;;
    "$BACK") home ;;
  esac
  for i in "${!devlines[@]}"; do
    if [ "${devlines[$i]}" = "$choice" ]; then
      local mac="${macs[$i]}"
      if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        bluetoothctl disconnect "$mac"; notify "切断しました"
      else
        bluetoothctl connect "$mac" && notify "接続しました" || notify "接続失敗"
      fi
      break
    fi
  done
}

# ---------- サウンド ----------
section_sound() {
  local vol muted state
  vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100)}')
  wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && muted=" 󰝟ミュート中" || muted=""
  # 出力一覧（id / name / 説明）。pactl はロケールでラベルが訳されるため LC_ALL=C で英語固定。
  mapfile -t sinks < <(LC_ALL=C pactl list sinks | awk '
    /^Sink #/{id=substr($2,2)}
    /^\tName: /{name=$2}
    /^\tDescription: /{$1="";sub(/^ /,"");print id"\x1f"name"\x1f"$0}')
  local def; def=$(pactl get-default-sink 2>/dev/null)
  local sinklines=() snames=()
  for s in "${sinks[@]}"; do
    IFS=$'\x1f' read -r sid sname sdesc <<<"$s"
    local m="  "; [ "$sname" = "$def" ] && m="󰸞 "
    snames+=("$sname"); sinklines+=("󰓃 ${m}${sdesc}")
  done

  local choice
  choice=$(printf '󰝝  音量 +5%%\n󰝞  音量 -5%%\n󰝟  ミュート切替\n%s\n󰍰  詳細 (pavucontrol)\n%s' \
    "$(printf '%s\n' "${sinklines[@]}")" "$BACK" | menu -p "サウンド  ${vol:-?}%${muted}")
  [ -z "$choice" ] && return
  case "$choice" in
    *+5*)   wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+; exec "$0" sound ;;
    *-5*)   wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-;        exec "$0" sound ;;
    *ミュート切替*) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; exec "$0" sound ;;
    *pavucontrol*)  pavucontrol & return ;;
    "$BACK") home ;;
  esac
  for i in "${!sinklines[@]}"; do
    [ "${sinklines[$i]}" = "$choice" ] && { pactl set-default-sink "${snames[$i]}"; notify "出力を切替"; exec "$0" sound; }
  done
}

# ---------- 画面の明るさ ----------
section_bright() {
  local cur; cur=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}')
  case "$(printf '󰃠  +10%%\n󰃞  -10%%\n󰃟  25%%\n󰃟  50%%\n󰃟  75%%\n󰃠  100%%\n%s' "$BACK" | menu -p "明るさ  現在 ${cur:-?}")" in
    *+10*) brightnessctl set 10%+ >/dev/null; exec "$0" bright ;;
    *-10*) brightnessctl set 10%- >/dev/null; exec "$0" bright ;;
    *25*)  brightnessctl set 25% >/dev/null;  exec "$0" bright ;;
    *50*)  brightnessctl set 50% >/dev/null;  exec "$0" bright ;;
    *75*)  brightnessctl set 75% >/dev/null;  exec "$0" bright ;;
    *100*) brightnessctl set 100% >/dev/null; exec "$0" bright ;;
    "$BACK") home ;;
  esac
}

# ---------- ディスプレイ ----------
section_display() {
  case "$(printf '󰍹  横/縦の配置を入れ替える\n%s' "$BACK" | menu -p "ディスプレイ")" in
    *入れ替え*) "$SCRIPTS/toggle-monitors.sh"; notify "ディスプレイ配置を入替" ;;
    "$BACK") home ;;
  esac
}

# ---------- ナイトライト ----------
section_night() {
  if pgrep -x wlsunset >/dev/null; then
    case "$(printf '󰔏  ナイトライトを OFF\n%s' "$BACK" | menu -p "ナイトライト: ON")" in
      *OFF*)  pkill -x wlsunset; notify "ナイトライト OFF" ;;
      "$BACK") home ;;
    esac
  else
    case "$(printf '󰔎  ナイトライトを ON（暖色）\n%s' "$BACK" | menu -p "ナイトライト: OFF")" in
      *ON*)   setsid wlsunset -l 35.7 -L 139.7 -t 3500 -T 6500 >/dev/null 2>&1 & notify "ナイトライト ON" ;;
      "$BACK") home ;;
    esac
  fi
}

# ---------- 電源プロファイル (tuned) ----------
section_tuned() {
  local active; active=$(tuned-adm active 2>/dev/null | sed 's/.*: //')
  mapfile -t profs < <(tuned-adm list 2>/dev/null | awk '/^- /{print $2}')
  local lines=()
  for p in "${profs[@]}"; do local m="  "; [ "$p" = "$active" ] && m="󰸞 "; lines+=("󰓅 ${m}${p}"); done
  local choice; choice=$(printf '%s\n%s' "$(printf '%s\n' "${lines[@]}")" "$BACK" | menu -p "電源プロファイル  現在: ${active:-?}")
  [ -z "$choice" ] && return
  [ "$choice" = "$BACK" ] && home
  for i in "${!lines[@]}"; do
    [ "${lines[$i]}" = "$choice" ] && { tuned-adm profile "${profs[$i]}" && notify "プロファイル: ${profs[$i]}" || notify "切替失敗（権限）"; break; }
  done
}

# ---------- 通知おやすみモード (dunst) ----------
section_dnd() {
  local paused; paused=$(dunstctl is-paused 2>/dev/null)
  local label="󰂚  おやすみモードを ON（通知を止める）"; [ "$paused" = "true" ] && label="󰂜  おやすみモードを OFF（通知を再開）"
  case "$(printf '%s\n%s' "$label" "$BACK" | menu -p "通知  $([ "$paused" = true ] && echo 停止中 || echo 通常)")" in
    *ON*)  dunstctl set-paused true;  notify "おやすみモード ON" ;;
    *OFF*) dunstctl set-paused false; notify "通知を再開" ;;
    "$BACK") home ;;
  esac
}

# ---------- スクリーンショット ----------
section_shot() {
  case "$(printf '󰩭  範囲を保存\n󰆏  範囲をコピー\n󰹑  全画面を保存\n󰆏  全画面をコピー\n%s' "$BACK" | menu -p "スクリーンショット")" in
    *範囲を保存*)   sleep 0.2; grimshot save area;   notify "範囲を保存" ;;
    *範囲をコピー*) sleep 0.2; grimshot copy area;   notify "範囲をコピー" ;;
    *全画面を保存*) grimshot save screen; notify "全画面を保存" ;;
    *全画面をコピー*) grimshot copy screen; notify "全画面をコピー" ;;
    "$BACK") home ;;
  esac
}

# ---------- ハブ ----------
main() {
  case "$(printf '%s\n' \
    "󰖩  WiFi" "󰂯  Bluetooth" "󰕾  サウンド" "󰃞  画面の明るさ" \
    "󰍹  ディスプレイ" "󰔎  ナイトライト" "󰓅  電源プロファイル" \
    "󰂚  通知（おやすみモード）" "󰹑  スクリーンショット" "󰐥  電源" \
    | menu -p "設定")" in
    *WiFi*)              exec "$0" wifi ;;
    *Bluetooth*)         exec "$0" bt ;;
    *サウンド*)          exec "$0" sound ;;
    *明るさ*)            exec "$0" bright ;;
    *ディスプレイ*)      exec "$0" display ;;
    *ナイトライト*)      exec "$0" night ;;
    *電源プロファイル*)  exec "$0" tuned ;;
    *通知*)              exec "$0" dnd ;;
    *スクリーンショット*) exec "$0" shot ;;
    *電源*)              exec "$SCRIPTS/power-menu.sh" ;;
  esac
}

case "${1:-}" in
  wifi) section_wifi ;;  bt) section_bt ;;       sound) section_sound ;;
  bright) section_bright ;;  display) section_display ;;  night) section_night ;;
  tuned) section_tuned ;;  dnd) section_dnd ;;   shot) section_shot ;;
  *) main ;;
esac
