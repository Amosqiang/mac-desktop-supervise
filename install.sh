#!/bin/bash
set -euo pipefail

# ============================================================================
# Mac Desktop Supervise - One-Click Installer (无需 Alfred，开箱即用)
# ============================================================================

ROOT="$(cd "$(dirname "$0")" && pwd)"
HS_DIR="$HOME/.hammerspoon"
STAMP="$(date +%Y%m%d_%H%M%S)"
BK_DIR="$HS_DIR/backups/install_${STAMP}"
RESET_CONFIG=false

for arg in "$@"; do
  case "$arg" in
    --reset-config) RESET_CONFIG=true ;;
  esac
done

echo ""
echo "=== Mac Desktop Supervise 一键安装 ==="
echo ""

# 1. Check Hammerspoon installation
HS_APP=""
if [ -d "/Applications/Hammerspoon.app" ]; then
  HS_APP="/Applications/Hammerspoon.app"
elif [ -d "$HOME/Applications/Hammerspoon.app" ]; then
  HS_APP="$HOME/Applications/Hammerspoon.app"
fi

if [ -z "$HS_APP" ]; then
  echo "[1/5] 未检测到 Hammerspoon。"
  if command -v brew >/dev/null 2>&1; then
    echo "      正在使用 Homebrew 自动安装 Hammerspoon..."
    brew install --cask hammerspoon
  else
    echo "      请先下载安装 Hammerspoon（免费开源）："
    echo "      https://www.hammerspoon.org/"
    echo "      安装完拖进「应用程序」后，重新运行 ./install.sh 即可。"
    exit 1
  fi
else
  echo "[1/5] 已检测到 Hammerspoon: $HS_APP"
fi

# 2. Backup existing ~/.hammerspoon files
mkdir -p "$HS_DIR/bin" "$BK_DIR"
echo "[2/5] 备份原有配置到 $BK_DIR ..."
for f in init.lua config.lua desk_layout.lua window_snap.lua mission_control.lua desk_layouts.json; do
  if [ -f "$HS_DIR/$f" ]; then
    cp "$HS_DIR/$f" "$BK_DIR/$f"
  fi
done

# 3. Copy core files
echo "[3/5] 安装核心脚本与跨桌面引擎..."
cp "$ROOT/hammerspoon/init.lua" "$HS_DIR/init.lua"
cp "$ROOT/hammerspoon/window_snap.lua" "$HS_DIR/window_snap.lua"
cp "$ROOT/hammerspoon/desk_layout.lua" "$HS_DIR/desk_layout.lua"
cp "$ROOT/hammerspoon/mission_control.lua" "$HS_DIR/mission_control.lua"
cp "$ROOT/hammerspoon/bin/spacectl" "$HS_DIR/bin/spacectl"
chmod +x "$HS_DIR/bin/spacectl"

# Remove macOS Gatekeeper quarantine flag on downloaded binary (safe if absent)
xattr -dr com.apple.quarantine "$HS_DIR/bin/spacectl" 2>/dev/null || true

# Preserve existing config.lua unless --reset-config is passed
if [ ! -f "$HS_DIR/config.lua" ] || [ "$RESET_CONFIG" = true ]; then
  cp "$ROOT/hammerspoon/config.lua" "$HS_DIR/config.lua"
  echo "      已写入默认配置文件: $HS_DIR/config.lua"
else
  echo "      已保留你原有的 $HS_DIR/config.lua（如需恢复默认请运行 ./install.sh --reset-config）"
fi

# 4. Disable macOS auto-rearranging Spaces (prevents Desktop 1/2/3/4 from shuffling)
echo "[4/5] 检查 macOS 多桌面顺序锁定设置..."
MRU="$(defaults read com.apple.dock mru-spaces 2>/dev/null || echo 1)"
if [ "$MRU" != "0" ]; then
  defaults write com.apple.dock mru-spaces -bool false
  killall Dock 2>/dev/null || true
  echo "      已自动关闭「根据最近使用自动重排空间」并刷新 Dock。"
else
  echo "      已锁定桌面顺序（mru-spaces = 0）。"
fi

# 5. Launch or reload Hammerspoon
echo "[5/5] 启动 / 重载 Hammerspoon..."
if pgrep -x Hammerspoon >/dev/null 2>&1; then
  open -g "hammerspoon://deskLayout?action=reload" || osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' 2>/dev/null || true
else
  open -g -a Hammerspoon
fi

echo ""
echo "============================================================"
echo "安装完成！接下来只需完成 1 次系统授权即可使用："
echo ""
echo "  1. 打开「系统设置 -> 隐私与安全性 -> 辅助功能」，勾选 Hammerspoon"
echo "  2. 首次恢复布局时，如果弹窗请求控制 Finder，点击「允许」"
echo ""
echo "默认快捷键（无需 Alfred 即可直接使用）："
echo "  Ctrl + Opt + Cmd + S       保存 / 覆盖当前桌面布局（会先预览窗口清单）"
echo "  Ctrl + Opt + Cmd + 1 ~ 9   一键切换到对应的工作区快照"
echo "  Ctrl + Opt + Cmd + W       呼出内置工作区搜索面板（模糊搜索 / 保存 / 删除）"
echo "  Ctrl + Opt + Cmd + R       重载配置"
echo "  Opt + Cmd + 方向键 / 回车   临时分屏（替代 Rectangle）"
echo "  Ctrl + Cmd + T / Y         左 1/3 <-> 右 1/3、左 2/3 <-> 右 2/3 切换"
echo ""
echo "个性化修改：直接编辑 ~/.hammerspoon/config.lua"
echo "（可选）如果你有 Alfred Powerpack，双击 alfred/Desk-Layout.alfredworkflow 即可导入 ws 面板。"
echo "============================================================"
