# 给 AI 助手（豆包 / Kimi / ChatGPT / Claude 等）的防错修改手册

如果你是用户：把本文件连同你的 `~/.hammerspoon/config.lua` 发给任意 AI，直接提出你的需求即可。  
如果你是 AI 助手：**请严格遵守以下规则**，不要猜测路径、不要随意改动核心引擎代码。

---

## 规则 1：99% 的修改只需要改 `~/.hammerspoon/config.lua`

用户的真实生效目录是 **`~/.hammerspoon/`**，结构如下：

```text
~/.hammerspoon/
├── config.lua           # 【唯一用户配置文件】改快捷键、白名单、隐藏/退出策略、菜单栏图标全在这里！
├── init.lua             # 入口脚本（不要改）
├── desk_layout.lua      # 跨桌面快照核心引擎（不要改）
├── window_snap.lua      # 临时分屏引擎（不要改）
├── mission_control.lua  # macOS 27 空间切换适配（不要改）
├── bin/spacectl         # 跨桌面底层通用二进制（Apple Silicon + Intel，不要改）
├── desk_layouts.json    # 自动生成的布局数据（一般无需手改）
├── backups/             # 每次覆盖前自动保留最近 10 份备份
└── desk_layout.log      # 运行日志（排错必看）
```

> **绝对禁止的错误**：不要让用户把配置写回 GitHub 下载目录而不同步；直接引导用户编辑 **`~/.hammerspoon/config.lua`**，改完按 **`Ctrl + Opt + Cmd + R`** 重载即可生效！

---

## 规则 2：8 个最高频定制的精确改法（直接照抄）

### 需求 A：某个软件在切换布局时不想被自动退出（加白名单）
1. 先让用户在终端运行以下命令获取软件的精确 Bundle ID（把 `WeChat` 换成软件名，如 `网易云音乐`、`Terminal`、`Notion`）：
   ```bash
   osascript -e 'id of app "软件名"'
   ```
2. 把返回的引号里的字符串加到 `~/.hammerspoon/config.lua` 的 `keepAliveApps` 数组中：
   ```lua
   keepAliveApps = {
     "io.github.clash-verge-ninja.clash-verge-ninja",
     "com.tencent.xinWeChat", -- 新加入的白名单软件
   },
   ```
3. 按 `Ctrl + Opt + Cmd + R` 重载。

### 需求 B：切换布局时不要退出其他软件（改成「隐藏」或「完全不管」）
修改 `~/.hammerspoon/config.lua` 中的 `otherAppsAction`：
- `"quit"`：直接退出不在布局里的软件（默认，最省内存）
- `"hide"`：仅隐藏到后台（等价于 `Cmd+H`，不会关闭未保存文档）
- `"none"`：完全不处理其他软件

### 需求 C：切换布局时不想关闭 Finder（访达）窗口
在 `~/.hammerspoon/config.lua` 中设置：
```lua
closeFinderOnRestore = false,
```

### 需求 D：想在顶部菜单栏看到 Hammerspoon 锤子图标（新手调试）
在 `~/.hammerspoon/config.lua` 中设置：
```lua
showMenuIcon = true,
```

### 需求 E：用户已经有 Rectangle / Magnet，想关闭本工具的分屏快捷键
在 `~/.hammerspoon/config.lua` 中设置：
```lua
enableWindowSnap = false,
```

### 需求 F：修改快捷键
Hammerspoon 的修饰键名**只能**写以下四个小写英文字符串：`"ctrl"`, `"alt"` (代表 Option), `"cmd"`, `"shift"`。  
示例（把保存/切换快捷键改成 `Cmd + Shift + S / 1~9`）：
```lua
layoutMods = { "cmd", "shift" },
saveKey = "s",
paletteKey = "w",
```
示例（修改左半屏快捷键为 `Ctrl + Opt + Left`）：
```lua
snapKeys = {
  leftHalf = { { "ctrl", "alt" }, "left" },
  -- 其余项保持不变
}
```

### 需求 G：保存快照时不想把某个临时软件存进去（防污染）
查出该软件 Bundle ID，加入 `ignoreOnCapture` 数组即可。

### 需求 H：没有 Alfred 怎么像 `ws` 一样搜索切换布局？
本工具已内置 macOS 原生搜索面板（基于 `hs.chooser`），**无需安装 Alfred**：
- 直接按 **`Ctrl + Opt + Cmd + W`** 即可弹出搜索框，支持中文/英文模糊搜索布局、回车一键切换、保存或删除布局。

---

## 规则 3：常见故障排查（按顺序检查）

1. **按快捷键完全没反应**：
   - 检查 Hammerspoon 是否在运行：`pgrep -x Hammerspoon`（无输出则运行 `open -g -a Hammerspoon`）。
   - 检查权限：**系统设置 -> 隐私与安全性 -> 辅助功能** 中是否勾选了 `Hammerspoon`（如果升级过 Hammerspoon，先减号移除再重新添加勾选）。
2. **窗口能缩放，但不能跨桌面移动**：
   - 终端运行 `~/.hammerspoon/bin/spacectl check` 检查权限与 macOS 兼容性。
   - 若提示「无法验证开发者 / 已损坏」，运行：
     ```bash
     xattr -dr com.apple.quarantine ~/.hammerspoon/bin/spacectl
     chmod +x ~/.hammerspoon/bin/spacectl
     ```
   - 确认已关闭自动重排空间：`defaults read com.apple.dock mru-spaces` 应返回 `0`。
3. **Finder 窗口没被关闭**：
   - 打开 **系统设置 -> 隐私与安全性 -> 自动化 -> Hammerspoon**，勾选 **Finder（访达）**。
4. **查看详细报错日志**：
   ```bash
   tail -n 40 ~/.hammerspoon/desk_layout.log
   ```
5. **隐藏菜单栏后怎么打开 Hammerspoon 控制台或重载**：
   - 重载配置：`open -g "hammerspoon://deskLayout?action=reload"`（或按 `Ctrl + Opt + Cmd + R`）
   - 打开控制台：`open "hammerspoon://deskLayout?action=console"`
6. **手滑覆盖错了布局怎么恢复**：
   - 查看 `~/.hammerspoon/backups/`，把最近的 `desk_layouts_YYYYMMDD_HHMMSS.json` 复制回 `~/.hammerspoon/desk_layouts.json` 即可。
