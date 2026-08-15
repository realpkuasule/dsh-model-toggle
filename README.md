# dsh-model-toggle

「本会话模型一键切换」按钮 —— DeepSeek-V4-Pro Max ↔ DeepSeek-V4-Flash Max，单击即切换**当前会话下一轮**使用的模型。

- 位置：输入框工具行右端（官方模型选择器旁边）
- 机制：走官方 wire API（`sessions.models` / `sessions.selectModel`），与官方模型选择器同源，切换后官方芯片同步
- 形态：web profile 客户端插件（`dsh.client` 双面包），浏览器端常驻，**不依赖动态插件**，重启 dsh 进程后按钮仍在
- 副作用：切换同时镜像写入默认模型（`agent-default-model`），影响之后新建的会话（与官方切换行为一致）

## 目录

```
package/           插件包（package.json + index.js host 壳 + client.js 浏览器端）
wire.sh            目标机器接线脚本（幂等：依赖 + pnpm install + patch 行）
install.sh         一键安装：本机或 SSH 远程（mbp / m4 / m2）
```

## 安装

```bash
./install.sh            # 本机
./install.sh m2         # SSH 远程（需 ~/.ssh/config 别名 + 免密）
```

然后**重启 dsh web 进程**（`pkill -f 'dsh web' && sleep 1 && dsh web`），刷新页面，输入框右侧出现 `⚡ Pro Max / Flash Max` 即成功。可重复执行（幂等）。

## 验证

按钮显示当前会话模型，单击变 `✓` 并切换；切换后官方模型选择器同步显示新模型；下一轮请求日志 `request/header` 的 model 字段即新模型。

## 依赖与兼容

- 依赖 DSH web profile 标准布局（`~/.dsh/profiles/web/`）与标准包（`dsh-api-remotes`、`dsh-client-connection`、`dsh-client-ui-slots` 等，随 dsh 发行自带）
- 与 DSH 版本耦合的接口：`conversation.input.right` slot、`sessions.models/selectModel` wire、`__ModuleLoader__` 客户端装载格式。跨版本升级后如按钮失效，先检查这三处签名
- 目标机器**无需 pnpm**：脚本优先 pnpm（offline→online），没有则自动改为手动 symlink（等价 hoisted 布局）

## 临时替代（不装包也能用）

动态插件版源码在会话里可随时重建：Host 半身处理 `session-model-status` / `toggle-session-model`（读写会话日志 `request/header`），Client 半身注册同一 slot。适合不想动 profile 的场合，但进程重启后消失。

## 同步到多台机器

```bash
./install.sh mbp && ./install.sh m4 && ./install.sh m2
```

各机器装完各自重启 dsh web 即可。
