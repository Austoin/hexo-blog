---
title: OpenCode MCP 配置完整流程：从安装到连通性验证
date: 2026-03-08 21:20:00
updated: 2026-03-08 21:20:00
tags: [OpenCode, MCP, Playwright, Fetch]
categories: [AI工具配置]
description: 基于官方文档的 OpenCode MCP 配置实战，包含本地 MCP 安装、opencode.json 配置、连通性验证、常见报错排查与发布流程。
cover: /img/cover/cover24.webp
top_img: /img/cover/cover24.webp
sticky: 1
---

## 前言

这篇文章记录我把 `fetch` 和 `playwright` 两个 MCP 服务器接入 OpenCode 的完整过程，重点是**按官方文档字段**配置，并且做真实可用性验证，不只看“connected”。

官方参考：<https://opencode.ai/docs/zh-cn/mcp-servers/>

## 一、先明确 OpenCode 的 MCP 配置位置

OpenCode 全局配置文件通常在：

```text
~/.config/opencode/opencode.json
```

Windows 对应示例：

```text
C:\Users\你的用户名\.config\opencode\opencode.json
```

> 如果你已经有配置，直接在原有 JSON 里追加 `mcp` 字段即可。

## 二、MCP 配置结构（官方要点）

根据官方文档，本地 MCP 服务器核心字段是：

- `type: "local"`
- `command: ["可执行命令", "参数1", "参数2"]`
- `enabled: true | false`
- `environment: { "KEY": "VALUE" }`（可选）
- `timeout: 5000`（可选，毫秒）

### 一个最小本地示例

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "my-local-mcp": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
      "enabled": true
    }
  }
}
```

## 三、安装并配置 fetch MCP

### 3.1 全局安装（Python 版 fetch）

```bash
uv tool install mcp-server-fetch
```

### 3.2 写入 OpenCode 配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "fetch": {
      "type": "local",
      "command": ["mcp-server-fetch"],
      "enabled": true,
      "environment": {
        "PYTHONIOENCODING": "utf-8"
      }
    }
  }
}
```

## 四、安装并配置 Playwright MCP

Playwright MCP 官方仓库：<https://github.com/microsoft/playwright-mcp>

### 4.1 安装

```bash
npm install -g @playwright/mcp
```

> 在 OpenCode 中，直接用 `npx @playwright/mcp@latest` 作为 command 更通用。

### 4.2 写入 OpenCode 配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["npx", "@playwright/mcp@latest"],
      "enabled": true
    }
  }
}
```

## 五、最终可用配置（fetch + playwright）

下面是我当前可工作的组合配置，直接可用：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "fetch": {
      "type": "local",
      "command": ["mcp-server-fetch"],
      "enabled": true,
      "environment": {
        "PYTHONIOENCODING": "utf-8"
      }
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "@playwright/mcp@latest"],
      "enabled": true
    }
  }
}
```

## 六、验证 MCP 是否真的能用

先看连接状态：

```bash
opencode mcp list
```

正常应看到类似：

```text
✓ fetch connected
✓ playwright connected
```

### 关键建议：别只看 connected

`connected` 只能说明“服务器可启动”，不一定代表“工具调用成功”。

建议至少做一次真实调用验证：

1. 调 `fetch` 抓一个网页（例如 HTTP 站点）
2. 调 `playwright` 执行一次最小操作（打开页面、snapshot）

## 七、常见坑与排查

### 7.1 字段名写错：`env` vs `environment`

OpenCode 这版 schema 用的是 `environment`。写成 `env` 可能出现：

```text
Configuration is invalid ... Invalid input mcp.xxx
```

### 7.2 HTTPS 证书错误（fetch 常见）

现象：

```text
CERTIFICATE_VERIFY_FAILED
```

这通常是本机证书链问题，不是 MCP 配置本身错误。可先用 HTTP 目标做功能验证，再处理证书链。

### 7.3 模型不可用导致 run 失败

有时 `opencode run` 报的是模型或账单问题，不代表 MCP 挂了。遇到这种情况，优先用：

```bash
opencode mcp list
```

再结合独立 MCP 调用做确认。

## 八、命令清单（可直接复制）

```bash
# 1) 安装 fetch MCP
uv tool install mcp-server-fetch

# 2) 安装 playwright MCP
npm install -g @playwright/mcp

# 3) 查看 MCP 状态
opencode mcp list

# 4) 对 OAuth 服务器认证（如 sentry）
opencode mcp auth <server-name>
```

## 总结

OpenCode 的 MCP 配置核心不复杂，关键在于三件事：

1. 字段严格按官方 schema 写（尤其 `command` 和 `environment`）
2. 先连通，再做真实工具调用
3. 报错先区分“配置问题”和“环境问题”（证书、模型、账单）

按这个流程走，基本可以稳定把本地和远程 MCP 跑起来。
