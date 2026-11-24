#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Alfred Script Filter for `ws` (Desk Layout workspace manager)."""

import json
import os
import sys
from collections import OrderedDict

STORE_PATH = os.path.expanduser("~/.hammerspoon/desk_layouts.json")
MAX_SLOTS = 9


def load_store():
    if not os.path.exists(STORE_PATH):
        return {"version": 1, "layouts": {}}
    try:
        with open(STORE_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("layouts"), dict):
            return data
    except Exception:
        pass
    return {"version": 1, "layouts": {}}


def next_free_slot(layouts):
    used = {v.get("slot") for v in layouts.values() if isinstance(v, dict) and v.get("slot")}
    for i in range(1, MAX_SLOTS + 1):
        if i not in used:
            return i
    return None


def summarize_layout(layout):
    windows = layout.get("windows") or []
    multi = (layout.get("monitorCount") or 1) > 1
    groups = {}
    for w in windows:
        di = w.get("displayIndex", 1)
        si = w.get("spaceIndex", 1)
        key = (di, si)
        if key not in groups:
            groups[key] = OrderedDict()
        label = w.get("appName") or w.get("name") or "?"
        groups[key][label] = groups[key].get(label, 0) + 1

    parts = []
    for (di, si) in sorted(groups.keys()):
        apps = [f"{k}x{c}" if c > 1 else k for k, c in groups[(di, si)].items()]
        prefix = f"屏{di}桌{si}" if multi else f"桌面{si}"
        parts.append(f"{prefix}: {', '.join(apps)}")
    return " · ".join(parts) if parts else "（空布局）"


def sorted_layouts(layouts):
    items = []
    for key, layout in layouts.items():
        if not isinstance(layout, dict):
            continue
        name = layout.get("name") or key
        slot = layout.get("slot")
        items.append((slot if isinstance(slot, int) else 999, name.lower(), name, layout))
    items.sort(key=lambda x: (x[0], x[1]))
    return [(x[2], x[3]) for x in items]


def find_existing(layouts, target_name):
    lower = target_name.lower()
    for key, layout in layouts.items():
        if not isinstance(layout, dict):
            continue
        name = layout.get("name") or key
        if name.lower() == lower or key.lower() == lower:
            return name, layout
    return None, None


def make_layout_item(name, layout):
    slot = layout.get("slot")
    win_count = len(layout.get("windows") or [])
    slot_tag = f"  [⌃⌥⌘{slot}]" if slot else ""
    summary = summarize_layout(layout)
    return {
        "uid": f"ws-layout-{name}",
        "title": f"{name}{slot_tag}",
        "subtitle": f"{win_count} 窗口 · {summary}",
        "arg": f"restore_name:{name}",
        "autocomplete": name,
        "mods": {
            "cmd": {
                "valid": True,
                "arg": f"save:{name}",
                "subtitle": f"⌘↩ 用当前桌面直接覆盖「{name}」",
            },
            "alt": {
                "valid": True,
                "arg": f"delete:{name}",
                "subtitle": f"⌥↩ 删除「{name}」" + (f"（释放 ⌃⌥⌘{slot}）" if slot else ""),
            },
        },
    }


def make_delete_item(name, layout):
    slot = layout.get("slot")
    slot_hint = f"（将释放 ⌃⌥⌘{slot}）" if slot else ""
    return {
        "uid": f"ws-del-{name}",
        "title": f"删除布局「{name}」{slot_hint}",
        "subtitle": summarize_layout(layout),
        "arg": f"delete:{name}",
    }


def main():
    raw_query = sys.argv[1] if len(sys.argv) > 1 else ""
    query = raw_query.strip()
    store = load_store()
    layouts = store.get("layouts") or {}
    ordered = sorted_layouts(layouts)

    items = []
    lower_q = query.lower()

    # Mode 1: `ws save <name>` or `ws s <name>`
    if lower_q == "save" or lower_q.startswith("save ") or lower_q.startswith("s "):
        target = query.split(None, 1)[1].strip() if " " in query else ""
        if not target:
            items.append({
                "title": "保存当前桌面布局…",
                "subtitle": "继续输入布局名称（例如 ws save Study），或回车弹出命名框",
                "arg": "save_interactive",
            })
        else:
            ex_name, ex_layout = find_existing(layouts, target)
            if ex_layout:
                slot = ex_layout.get("slot")
                slot_hint = f" [保持 ⌃⌥⌘{slot}]" if slot else ""
                items.append({
                    "title": f"覆盖布局「{ex_name}」{slot_hint}",
                    "subtitle": f"覆盖前自动备份旧版本 · 原内容: {summarize_layout(ex_layout)}",
                    "arg": f"save:{ex_name}",
                })
            else:
                free = next_free_slot(layouts)
                slot_hint = f" -> 分配 ⌃⌥⌘{free}" if free else "（槽位已满，可通过 ws 恢复）"
                items.append({
                    "title": f"新建布局「{target}」{slot_hint}",
                    "subtitle": "直接保存当前全部桌面的窗口布局",
                    "arg": f"save:{target}",
                })

    # Mode 2: `ws del [name]` / `ws rm [name]` / `ws delete [name]`
    elif lower_q in ("del", "rm", "delete") or lower_q.startswith(("del ", "rm ", "delete ")):
        keyword = query.split(None, 1)[1].strip().lower() if " " in query else ""
        for name, layout in ordered:
            if not keyword or keyword in name.lower():
                items.append(make_delete_item(name, layout))
        if not items:
            items.append({
                "title": "没有匹配的布局可删除",
                "subtitle": "检查名称或直接输入 ws 查看已有布局",
                "valid": False,
            })

    # Mode 3: List / fuzzy search layouts
    else:
        for name, layout in ordered:
            summary = summarize_layout(layout)
            if not lower_q or lower_q in name.lower() or lower_q in summary.lower():
                items.append(make_layout_item(name, layout))

        if not query:
            items.append({
                "uid": "ws-save-interactive",
                "title": "保存当前桌面为新布局…",
                "subtitle": "也可直接输入 ws save <名称> 或 ws del <名称>",
                "arg": "save_interactive",
            })
        elif not items:
            free = next_free_slot(layouts)
            slot_hint = f" -> 分配 ⌃⌥⌘{free}" if free else ""
            items.append({
                "title": f"新建布局「{query}」{slot_hint}",
                "subtitle": "未找到同名布局，回车直接将当前桌面保存为该名称",
                "arg": f"save:{query}",
            })

    print(json.dumps({"items": items}, ensure_ascii=False))


if __name__ == "__main__":
    main()
