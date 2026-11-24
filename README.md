# Mac Desktop Supervise — macOS 一键工作区快照与切换引擎

> **无需 Alfred、无需付费软件、菜单栏 0 图标。**  
> 一键把整台 Mac 的多个桌面保存成「代码一样的快照」，随时一键切换（日常 / 论文 / 纯编程）、一键清场（关闭乱飞的 Finder 和无关弹窗），还顺手 1:1 替代了 Rectangle 分屏。

[English Guide below](#english-guide) · [给豆包 / AI 助手的修改指南](./GUIDE_FOR_AI.md)

---

## 核心功能

- **多场景一键秒切**：按 `Ctrl + Opt + Cmd + 1 / 2 / 3 ...` 在不同工作区之间瞬间切换（例如 `Base` 日常全套、`Study` 专注读论文、`Focus` 纯代码模式），自动关闭乱飞的 Finder 窗口并清退无关软件。
- **无需 Alfred 也能用**：仅需免费开源的 **Hammerspoon**！内置搜索面板（`Ctrl + Opt + Cmd + W`），支持模糊搜索切换、保存和删除布局。
- **防污染快照 + 自动备份**：按 `Ctrl + Opt + Cmd + S` 保存前会先列出每个桌面捕获到的窗口清单，自动过滤活动监视器/系统设置等杂窗；每次覆盖前自动备份旧版本到 `~/.hammerspoon/backups/`（保留最近 10 份）。
- **隐形常驻，直接替代 Rectangle**：菜单栏和 Dock 均不占图标，内置零延迟分屏快捷键，支持 `Ctrl+Cmd+T`（左 1/3 / 右 1/3 切换）和 `Ctrl+Cmd+Y`（左 2/3 / 右 2/3 切换）。
- **（可选）Alfred Powerpack 联动**：附带双击即装的 `alfred/Desk-Layout.alfredworkflow`，输入 `ws` 即可可视化管理全部工作区。

---

## 零基础 3 步安装（约 1 分钟）

### 第 1 步：下载本项目
- **方式 A（终端命令）**：
  ```bash
  git clone https://github.com/Amosqiang/mac-desktop-supervise.git
  cd mac-desktop-supervise
  ```
- **方式 B（不会用 git）**：点击页面右上角绿色 **`Code`** 按钮 -> **`Download ZIP`** -> 解压后打开「终端（Terminal）」，输入 `cd `（带空格），把解压后的文件夹拖进终端窗口并回车。

### 第 2 步：运行一键安装脚本
在终端执行：
```bash
./install.sh
```
脚本会自动完成：
1. 检测（或用 Homebrew 自动安装）免费开源的 **Hammerspoon**（如未装 Homebrew，按提示去 [hammerspoon.org](https://www.hammerspoon.org/) 下载拖进应用程序即可）
2. 备份你原有的 `~/.hammerspoon/` 配置
3. 安装脚本与跨桌面引擎 `spacectl`（同时支持 Apple Silicon M 芯片与 Intel Mac）
4. 自动关闭 macOS「根据最近使用自动重新排列空间」，防止桌面 1/2/3/4 顺序乱跳
5. 自动启动 Hammerspoon

### 第 3 步：完成 1 次系统授权
1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能（Accessibility）**，打开 **Hammerspoon** 的开关。
2. 首次切换布局时，若系统弹窗询问「Hammerspoon 想要控制访达（Finder）」，点击 **允许**。

> 建议同时在 **系统设置 -> 键盘 -> 键盘快捷键 -> 调度中心** 里勾选「切换到桌面 1 / 2 / 3 / 4」（`Ctrl + 1~4`），日常切桌面极快！

---

## 快捷键速查（无需 Alfred 开箱即用）

| 快捷键 | 功能 |
| :--- | :--- |
| **`Ctrl + Opt + Cmd + S`** | 保存 / 覆盖当前桌面布局（弹窗先预览窗口清单；同名覆盖，新名自动分配下一个槽位） |
| **`Ctrl + Opt + Cmd + 1 ~ 9`** | 一键切换到对应槽位的工作区快照 |
| **`Ctrl + Opt + Cmd + W`** | 呼出**内置工作区搜索面板**（无 Alfred 也能搜、切、存、删） |
| **`Ctrl + Opt + Cmd + R`** | 修改配置后一键重载 |
| **`Opt + Cmd + 方向键 / 回车`** | 临时分屏：左半 / 右半 / 上半 / 下半 / 最大化（多屏连按左右可跨屏） |
| **`Ctrl + Cmd + T`** | 左 1/3 与右 1/3 来回切换 |
| **`Ctrl + Cmd + Y`** | 左 2/3 与右 2/3 来回切换 |

### （可选）如果你有 Alfred Powerpack
直接双击 [alfred/Desk-Layout.alfredworkflow](./alfred/Desk-Layout.alfredworkflow) 导入，即可在 Alfred 中输入 `ws`：
- `ws`：列出全部布局与窗口摘要（`Enter` 切换、`Cmd + Enter` 覆盖、`Opt + Enter` 删除）
- `ws save 名称`：免弹窗直接保存/覆盖
- `ws del 名称`：删除布局并释放槽位

---

## 怎么改成你自己的习惯？（只改 1 个文件，甚至直接丢给豆包改）

所有个性化选项都集中在 **`~/.hammerspoon/config.lua`** 这一个文件里，注释非常清晰：

| 你想改什么 | 修改 `~/.hammerspoon/config.lua` 中的这一项 |
| :--- | :--- |
| 切换布局时**不要退出**其他软件，只隐藏到后台 | `otherAppsAction = "hide"`（默认 `"quit"`，完全不管可改 `"none"`） |
| 把某个软件加入**永不退出白名单** | 在 `keepAliveApps = { ... }` 里加上它的 Bundle ID |
| 在顶部菜单栏**显示 Hammerspoon 图标** | `showMenuIcon = true` |
| 想继续用 Rectangle / Magnet，关闭内置分屏 | `enableWindowSnap = false` |
| 自定义任何快捷键 | 修改 `layoutMods` / `saveKey` / `paletteKey` / `snapKeys` |

改完保存后，按 **`Ctrl + Opt + Cmd + R`** 立即生效！

### 懒人技巧：直接把本项目喂给豆包 / ChatGPT / Kimi 帮你改
本仓库专门准备了 [GUIDE_FOR_AI.md](./GUIDE_FOR_AI.md)（写给任何 AI 的防幻觉操作手册）。你只要把 `GUIDE_FOR_AI.md` 和你本地的 `~/.hammerspoon/config.lua` 发给 **豆包 / Kimi / ChatGPT**，说：

> 「请严格按照这份指南，帮我修改 `config.lua`：把微信和音乐加入永不退出白名单，把切换时退出其他软件改成只隐藏，然后告诉我改完怎么重载。」

哪怕最基础的对话 AI 也能 100% 准确给出修改后的代码和命令。

---

## 卸载方式
```bash
./uninstall.sh
```
只会移除本工具脚本，不会删除你保存的历史快照与备份。

---

<a id="english-guide"></a>

## English Guide

**Mac Desktop Supervise** turns your macOS Spaces into Git-like workspace snapshots using **only free, open-source Hammerspoon** (zero menu bar icons, no Alfred required, and optional 1:1 Rectangle replacement).

### 1-Minute Setup
```bash
git clone https://github.com/Amosqiang/mac-desktop-supervise.git
cd mac-desktop-supervise
./install.sh
```
Then open **System Settings -> Privacy & Security -> Accessibility** and enable **Hammerspoon**.

### Default Shortcuts (Works Standalone Without Alfred)
- **`Ctrl + Opt + Cmd + S`**: Save or overwrite a named workspace snapshot (previews captured windows, auto-filters junk apps like Activity Monitor, auto-backs up before overwriting).
- **`Ctrl + Opt + Cmd + 1..9`**: 1-key switch to workspace slot 1–9 (closes stray Finder windows and cleans up unused apps).
- **`Ctrl + Opt + Cmd + W`**: Built-in fuzzy workspace switcher palette (no Alfred needed).
- **`Ctrl + Opt + Cmd + R`**: Reload config after editing `~/.hammerspoon/config.lua`.
- **`Opt + Cmd + Arrows / Return`** & **`Ctrl + Cmd + T / Y`**: Instant 0ms window tiling (1/2, maximize, Left/Right 1/3 & 2/3 toggle).

### Optional Alfred Powerpack Integration
Double-click [`alfred/Desk-Layout.alfredworkflow`](./alfred/Desk-Layout.alfredworkflow) and type `ws` in Alfred (`Enter` to switch, `Cmd+Enter` to overwrite, `Opt+Enter` to delete).

### Customization
Edit `~/.hammerspoon/config.lua` (single file for all settings: `otherAppsAction = "quit" | "hide" | "none"`, `keepAliveApps`, `showMenuIcon`, `enableWindowSnap`, and all hotkeys), then press **`Ctrl + Opt + Cmd + R`**. See [`GUIDE_FOR_AI.md`](./GUIDE_FOR_AI.md) for copy-paste AI customization instructions.
