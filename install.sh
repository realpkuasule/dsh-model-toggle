#!/usr/bin/env bash
# install.sh — 把「本会话模型一键切换」按钮装到一台机器的 dsh web profile。
#
# 用法：
#   ./install.sh            # 本机
#   ./install.sh mbp        # SSH 到 mbp（需 ssh config 别名 + 免密）
#   ./install.sh m4
#   ./install.sh m2
#
# 装完后在目标机器上重启 dsh web 进程生效：
#   pkill -f 'dsh web' && sleep 1 && dsh web
# （远程机器请自行或委托执行重启；本脚本不重启任何 dsh 服务。）
set -euo pipefail
cd "$(dirname "$0")"
HOST="${1:-}"

if [ -z "$HOST" ]; then
    echo "== 本机安装 =="
    TMP="$(mktemp -d)"
    rsync -a --delete package/ "$TMP/pkg/"
    rm -rf "$HOME/.dsh/profiles/web/packages/model-toggle"
    mkdir -p "$HOME/.dsh/profiles/web/packages/model-toggle"
    rsync -a "$TMP/pkg/" "$HOME/.dsh/profiles/web/packages/model-toggle/"
    rm -rf "$TMP"
    PROFILE="$HOME/.dsh/profiles/web" bash wire.sh
else
    echo "== 远程安装: $HOST =="
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST" 'mkdir -p /tmp/dsh-model-toggle-install' || { echo "install: 无法连接 $HOST" >&2; exit 1; }
    rsync -a --delete package/ -e 'ssh -o BatchMode=yes' "$HOST":/tmp/dsh-model-toggle-install/pkg/
    rsync -a wire.sh -e 'ssh -o BatchMode=yes' "$HOST":/tmp/dsh-model-toggle-install/wire.sh
    ssh -o BatchMode=yes "$HOST" '
        set -euo pipefail
        rm -rf "$HOME/.dsh/profiles/web/packages/model-toggle"
        mkdir -p "$HOME/.dsh/profiles/web/packages/model-toggle"
        rsync -a /tmp/dsh-model-toggle-install/pkg/ "$HOME/.dsh/profiles/web/packages/model-toggle/"
        PROFILE="$HOME/.dsh/profiles/web" bash /tmp/dsh-model-toggle-install/wire.sh
        rm -rf /tmp/dsh-model-toggle-install
    '
    echo "== $HOST 安装完成；请在该机器上重启 dsh web =="
fi
