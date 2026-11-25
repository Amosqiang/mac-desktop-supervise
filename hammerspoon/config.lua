-- ============================================================================
-- Mac Desktop Supervise - User Configuration (唯一需要修改的配置文件)
-- ============================================================================
-- 修改本文件后，按 Ctrl+Opt+Cmd+R（或终端运行：
--   open -g "hammerspoon://deskLayout?action=reload"
-- ）即可立即生效。
-- ============================================================================

return {
  -- 1. 外观与开机自启 (Appearance & Auto-Launch)
  showMenuIcon = false, -- false = 菜单栏完全隐形；true = 顶部显示锤子图标（新手调试可改 true）
  showDockIcon = false, -- false = Dock 不显示图标
  autoLaunch = true,    -- true = 开机自动启动 Hammerspoon

  -- 2. 内置快捷键（开箱即用！）
  --   "auto" = 推荐默认：未运行 Alfred 时自动启用全部快捷键；检测到 Alfred 运行时自动让出 ⌃⌥⌘S / 1~9 避免冲突（⌃⌥⌘W 面板始终可用）
  --   true   = 始终由 Hammerspoon 接管全部快捷键
  --   false  = 关闭全部内置布局快捷键
  enableBuiltInHotkeys = "auto",
  layoutMods = { "ctrl", "alt", "cmd" }, -- 布局控制修饰键，默认 Ctrl + Option + Command
  saveKey = "s",                         -- 保存/覆盖当前布局：Ctrl+Opt+Cmd + S
  paletteKey = "w",                      -- 呼出内置 1:1 Alfred 级工作区搜索面板：Ctrl+Opt+Cmd + W
  reloadKey = "r",                       -- 重载配置：Ctrl+Opt+Cmd + R
  maxHotkeySlots = 9,                    -- 自动绑定 Ctrl+Opt+Cmd + 1 ~ 9

  -- 3. 恢复/切换布局时，如何处理「不在目标布局里的其他软件」？
  --   "quit" = 直接退出（最省内存、最干净，推荐）
  --   "hide" = 仅隐藏到后台（不关闭未保存文档，更安全）
  --   "none" = 不动其他软件，只归位目标布局里的窗口
  otherAppsAction = "quit",

  -- 恢复/切换布局时，是否自动关闭所有 Finder（访达）窗口？
  closeFinderOnRestore = true,

  -- 4. 永不退出的软件白名单（填入 macOS Bundle ID）
  -- 查任意软件 Bundle ID 的终端命令：osascript -e 'id of app "软件名"'
  keepAliveApps = {
    "io.github.clash-verge-ninja.clash-verge-ninja", -- Clash Verge（代理软件）
    -- "com.apple.Terminal",                         -- 示例：取消前面 -- 即可保留终端
    -- "com.googlecode.iterm2",                      -- 示例：保留 iTerm2
  },

  -- 5. 保存快照时自动忽略的临时工具（防污染，不写入快照；切换时仍会按第 3 项规则清理）
  ignoreOnCapture = {
    "com.apple.ActivityMonitor",   -- 活动监视器
    "com.apple.systempreferences", -- 系统设置
    "com.apple.Preview",           -- 预览
    "com.apple.Console",           -- 控制台
    "com.apple.QuickTimePlayerX",  -- QuickTime
    "com.apple.screencaptureui",   -- 截屏
    "com.apple.archiveutility",    -- 归档实用工具
  },

  -- 6. 左侧 Option + 1~4 快速切桌面（完全不拦截右侧 Option，不影响豆包等语音输入键！）
  -- 依赖系统设置「键盘快捷键 -> 调度中心 -> 切换到桌面 1~4」已勾选（默认 Ctrl+1~4）
  enableLeftOptSpaceSwitch = true,
  leftOptSpaceCount = 4, -- 支持左 Option + 1 ~ 4（可按桌面数量改为 1 ~ 9）

  -- 7. 临时窗口分屏快捷键（1:1 替代 Rectangle；不需要分屏可设为 false）
  enableWindowSnap = true,
  snapKeys = {
    leftHalf        = { { "alt", "cmd" }, "left" },   -- 左半屏（多屏下连按跨屏）
    rightHalf       = { { "alt", "cmd" }, "right" },  -- 右半屏（多屏下连按跨屏）
    topHalf         = { { "alt", "cmd" }, "up" },     -- 上半屏
    bottomHalf      = { { "alt", "cmd" }, "down" },   -- 下半屏
    maximize        = { { "alt", "cmd" }, "return" }, -- 最大化
    toggleThird     = { { "ctrl", "cmd" }, "t" },     -- 左 1/3 <-> 右 1/3 来回切换
    toggleTwoThirds = { { "ctrl", "cmd" }, "y" },     -- 左 2/3 <-> 右 2/3 来回切换
  },
}
