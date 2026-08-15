#!/usr/bin/env bash
# wire.sh — 在目标机器上把 model-toggle 接线进 dsh web profile（幂等，可重复执行）。
# 前置：package/ 内容已就位（install.sh 负责放置）。
# 用法：PROFILE=~/.dsh/profiles/web ./wire.sh
set -uo pipefail
PROFILE="${PROFILE:-$HOME/.dsh/profiles/web}"
PKG="$PROFILE/packages/model-toggle"
[ -f "$PKG/package.json" ] || { echo "wire: 找不到 $PKG/package.json" >&2; exit 1; }

# 1) package.json 依赖（幂等）
python3 - "$PROFILE/package.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
deps = data.setdefault("dependencies", {})
if "model-toggle" not in deps:
    deps["model-toggle"] = "file:./packages/model-toggle"
    with open(p, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("wire: package.json 依赖已添加")
else:
    print("wire: package.json 依赖已存在")
PY

# 2) 链接 model-toggle 到可解析的 node_modules
#    优先 pnpm（offline→online）；没有 pnpm 则手动 symlink（等价 hoisted 布局）。
LINKED=0
if command -v pnpm >/dev/null 2>&1; then
    if (cd "$PROFILE" && pnpm install --offline >/dev/null 2>&1) || (cd "$PROFILE" && pnpm install >/dev/null 2>&1); then
        echo "wire: pnpm install 完成"
        LINKED=1
    else
        echo "wire: pnpm install 失败，尝试手动 symlink" >&2
    fi
else
    echo "wire: 未安装 pnpm，改用手动 symlink"
fi
if [ "$LINKED" -ne 1 ]; then
    ABS="$(cd "$PKG" && pwd)"
    NMD=""
    [ -d "$PROFILE/node_modules" ] && NMD="$PROFILE/node_modules"
    if [ -z "$NMD" ] && [ -d "$(dirname "$PROFILE")/node_modules" ]; then NMD="$(dirname "$PROFILE")/node_modules"; fi
    if [ -z "$NMD" ]; then mkdir -p "$PROFILE/node_modules"; NMD="$PROFILE/node_modules"; fi
    mkdir -p "$NMD"
    ln -sfn "$ABS" "$NMD/model-toggle"
    echo "wire: symlink $NMD/model-toggle -> $ABS"
fi

# 3) cordis.patch.yml 行（幂等；先备份）
PATCH="$PROFILE/cordis.patch.yml"
if ! grep -q "name: 'model-toggle'" "$PATCH"; then
    cp "$PATCH" "$PATCH.bak-model-toggle"
    python3 - "$PATCH" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    text = f.read()
row = (
    "    # 本会话模型一键切换按钮（⚡ Pro Max ↔ Flash Max），走官方 wire API。\n"
    "    # 见 packages/model-toggle/。\n"
    "    - id: model-toggle\n"
    "      name: 'model-toggle'\n"
)
if "model-toggle" in text:
    print("wire: cordis.patch.yml 已包含 model-toggle")
else:
    marker = "    - id: lan-gate\n"
    if marker in text:
        text = text.replace(marker, row + marker)
    else:
        text += "\n- insert:\n" + row
    with open(p, "w") as f:
        f.write(text)
    print("wire: cordis.patch.yml 行已添加（备份在 .bak-model-toggle）")
PY
else
    echo "wire: cordis.patch.yml 行已存在"
fi

# 4) 校验：node 能否从 profile 解析到包
if command -v node >/dev/null 2>&1; then
    node -e "const p=require('path');const {createRequire}=require('module');const r=createRequire(require('path').join(process.env.HOME,'.dsh/profiles/web/package.json'));try{console.log('wire: 解析OK ->',r.resolve('model-toggle'))}catch(e){console.log('wire: 解析失败 -> '+e.message.split('\n')[0])}"
else
    echo "wire: 远端无 node，跳过解析校验"
fi
echo "wire: 完成。请重启 dsh web 进程使按钮生效（重启后刷新页面）。"
