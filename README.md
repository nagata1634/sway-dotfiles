# sway-dotfiles

Fedora **Sway Atomic (Sericea)** 向けの Sway デスクトップ環境一式。
Catppuccin Mocha で配色を統一し、Wayland ネイティブ構成でまとめています。

![wm: sway](https://img.shields.io/badge/wm-sway-89b4fa) ![distro: Fedora Atomic](https://img.shields.io/badge/distro-Fedora%20Atomic-cba6f7)

## 含まれるもの

| パス | 役割 |
|---|---|
| `.config/sway/` | Sway 本体・出力(モニタ)設定・各種スクリプト |
| `.config/rofi/` | rofi テーマ（Catppuccin Mocha） |
| `.config/fuzzel/` | fuzzel（Wayland ネイティブ・**日本語入力対応**のランチャー） |
| `.config/waybar/` | ステータスバー |
| `.config/dunst/` | 通知 |

### 設計のポイント

- **ランチャー二段構え**: 日本語入力が要る用途（アプリ検索 `Super+d` / ウィンドウ切替 `Super+Tab`）は
  Wayland ネイティブの **fuzzel**、それ以外の定型メニュー（電源・設定・通知・キーバインド一覧）は
  **rofi + meta 隠し検索**（日本語表示の項目をローマ字/英字で絞り込める）。
- **無停止フォールバック**: `fuzzel`/`wezterm`(RPM) が未導入でも `launcher.sh`/`term.sh` が
  rofi / Flatpak 版へ自動フォールバックするため、導入前でも壊れない。
- **キーバインド一覧**: `Super+Shift+/` で全バインドを「キー → 機能名」で表示（`config` 内の
  `#: 機能名` コメントから生成）。
- **マルチモニタ自動整列**: `apply-displays.py` が同型モニタを接続名順で横/縦に割り当て。

## 主なキーバインド

| キー | 機能 |
|---|---|
| `Super+Return` | ターミナル（wezterm） |
| `Super+d` | アプリランチャー（fuzzel・日本語検索可） |
| `Super+Tab` | ウィンドウ切替 |
| `Super+Shift+/` | キーバインド一覧 |
| `Super+x` | 電源メニュー |
| `Super+Ctrl+s` | 設定ハブ（WiFi/音/明るさ等） |
| `Super+`\` | スクラッチパッド表示 |

## 導入

### 手動

```sh
git clone https://github.com/nagata1634/sway-dotfiles.git
cp -r sway-dotfiles/.config/* ~/.config/    # またはシンボリックリンク
```

依存パッケージ（Fedora Atomic ではベース外を `rpm-ostree install` でレイヤリング）:

```
wezterm fuzzel fcitx5 fcitx5-autostart fcitx5-mozc
```

`rofi waybar dunst brightnessctl pavucontrol NetworkManager wireplumber` 等はベースイメージ提供。

### 自動

セットアップを自動化する別リポ（プライベート）の `install.sh` から、パッケージのレイヤリングと
本リポの配置をまとめて実行できます。

## 注意

- 壁紙画像は含めていません。`~/Pictures/background/` に各自配置してください
  （`config` / `config.d/10-outputs.conf` のパスを参照）。
- モニタ設定（`config.d/10-outputs.conf`, `apply-displays.py`）は KTC H27T27 ×2 前提のため、
  自分の環境に合わせて編集してください。
