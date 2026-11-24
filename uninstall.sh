#!/bin/bash
set -euo pipefail

HS_DIR="$HOME/.hammerspoon"
echo "正在卸载 Mac Desktop Supervise..."
osascript -e 'tell application "Hammerspoon" to quit' 2>/dev/null || true
rm -f "$HS_DIR/init.lua" "$HS_DIR/config.lua" "$HS_DIR/desk_layout.lua" "$HS_DIR/window_snap.lua" "$HS_DIR/space_switch.lua" "$HS_DIR/mission_control.lua" "$HS_DIR/bin/spacectl"
echo "已移除核心脚本（你的布局快照 desk_layouts.json 与 backups/ 仍保留在 ~/.hammerspoon 中，如需彻底删除请手动移除）。"
