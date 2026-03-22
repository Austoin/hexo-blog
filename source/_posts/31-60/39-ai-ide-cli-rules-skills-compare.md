---
title: AI IDE / CLI 的 Rules 与 Skills 对比笔记
date: 2026-03-22 23:30:00
updated: 2026-03-22 23:30:00
tags: [AI工具, Codex, Claude Code, Cursor, Trae, Gemini CLI, OpenCode]
categories: [AI工具配置]
description: 多种 AI IDE 与 CLI 的 rules、skills 与使用差异对比笔记。
cover: /img/cover/cover39.webp
top_img: /img/cover/cover39.webp
---

这篇文章整理多种 AI IDE / CLI 的 rules、skills、上下文与常见工作流差异。

**文章来源**：<https://linux.do/t/topic/1794526>

> 说明：本文基于原帖内容做了整理、删减与重组，并结合个人使用习惯保留了更适合长期查阅的部分。此类工具更新很快，涉及额度、价格、会员权益、封号风控等信息时，请以官方最新说明为准。

## 本文使用“对比式学习法”

最近我更喜欢用“对比式学习法”学习 AI 工具：同一主题不只看一个产品，而是同时对比 2~n 个工具。

这样做不一定需要线性增加时间，但能更快建立“共性”和“差异”的认识。很多功能如果只看单一产品，会以为那是“理所当然”；一旦放到多个 IDE / CLI 里横向比较，就能更容易看出哪些是通用设计，哪些只是某个产品自己的实现方式。

___

## Rules 和 Skills 的核心区别

### Skill 通用

- skill 名称通常需要与 `SKILL.md` 里的 `name` 保持一致
- 一般建议使用下划线或稳定命名，不要频繁改名
- 项目级 skill 往往会覆盖同名全局 skill

### Rules 通用

- rules 更像“自动注入的约束”或“固定提示词”
- 是否进入 system prompt、user prompt，是否会被压缩，取决于各家实现
- 自动加载规则通常更稳定；手动或按条件触发的规则，更像可选补充

___

## 各工具的 rules / skills 位置

### Antigravity

- **全局 rules**：`C:/Users/用户名/.gemini/GEMINI.md`
- **项目全局 rules**：无单独固定文件
- **项目 rules**：`{workspace}/.agent/rules/*.md`
- **规则触发**：`always_on` / `model_decision` / `manual` / `glob`
- **skills**：`.agent/skills/名称/SKILL.md`

### Cursor

- **全局 rules**：通常不以 `.md` 文件形式直接暴露，更多在产品配置或数据库层
- **项目 rules**：`.cursor/rules/*.md`
- **规则触发**：通常在 UI 中配置，常见概念包括 `Auto` / `Manual` / `Glob` / `AI match`
- **skills**：`.cursor/skills/名称/SKILL.md`
- **补充**：可在 `config.toml` 里通过 `skills.config[].path` 指向额外目录

### Trae

- **全局 rules**：`Users/用户名/.trae-cn/user_rules.md`
- **项目 rules**：`{workspace}/.trae/rules/*.md`
- **skills**：通常放在对应 skills 目录中
- **补充**：没有很独立的“AI 决定”按钮时，可通过 `alwaysApply: false` 配合 `description` / `globs` 模拟条件触发

### Codex

- **工作区 rules**：`{workspace}/AGENTS.md`
- **覆盖文件**：`AGENTS.override.md`
- **作用范围**：可放在 workspace 根目录或子目录；子目录规则只影响对应子树
- **skills**：`.agent/skills/名称/SKILL.md`

### Claude Code

- **全局 rules**：`Users/用户名/.claude/CLAUDE.md`
- **项目全局 rules**：`{workspace}/CLAUDE.md`
- **项目 rules**：`{workspace}/.claude/rules/*.md`
- **子目录 rules**：`{workspace}/子目录/CLAUDE.md`
- **skills**：`.claude/skills/名称/SKILL.md`
- **补充**：rules 常见写法是通过 `paths` 做路径匹配，由模型自行决定在何时重点使用

### Kilo Code

- **全局 rules**：`Users/用户名/.kilocode/rules/*.md`
- **项目 rules**：`{workspace}/.kilocode/rules/*.md`
- **全局 skills**：`~/.kilocode/skills/名称/SKILL.md`
- **项目 skills**：`{workspace}/.kilocode/skills/名称/SKILL.md`

### Lingma / CodeBuddy

这两类工具在 rules / skills 的公开约定上相对没那么统一。实际使用时，更建议直接看其当前版本文档、设置面板或产品说明，而不是硬套其他工具的目录结构。

___

## 同步与映射

### 相同 IDE，不同 workspace

如果你只是想在多个项目之间复用同一套规则，最省事的方法通常是直接同步整个 rules / skills 目录。

例如：

```text
把 {workspace1}/.agent 映射到 {workspace2}/.agent
```

### 不同 IDE，同一 workspace

如果你已经在某个 IDE 里维护了一套规则，迁移到其他 IDE 时，常见做法是“目录映射”或“按文件映射”。

例如：

```text
把 {workspace}/.agent 映射到 {workspace}/.cursor
```

### 文件夹映射 vs 单文件映射

**文件夹映射**：

- 优点：一次性同步所有规则，维护成本低
- 缺点：两个目录会高度一致，不方便保留某个 IDE 的私有规则

**单文件映射**：

- 优点：可以只同步公共部分，私有规则保留在各自目录
- 缺点：数量一多就比较难维护

### 文件名不同但语义相同的映射

这类情况很常见，例如把 Antigravity 的 `GEMINI.md` 映射到 Codex 的 `AGENTS.md`。本质不是“同名同步”，而是“语义对齐”。

___

## `.gitignore` 与 AI 访问

### 通用位置

```text
{workspace}/.gitignore
```

这是一个文件，不是文件夹。

### 需要注意的差异

- **Antigravity**：通常会参考忽略规则
- **Codex**：Git 忽略和 AI 搜索范围不一定完全等价，是否忽略要看具体能力实现
- **Kilo Code**：还有自己的一套忽略文件，常见写法类似 `.kilocodeignore`

结论是：不要默认认为“被 Git 忽略 = 一定不会被 AI 访问”。这两套机制经常不是一回事。

___

## 上下文与压缩

这是 AI IDE / CLI 最容易被忽视、但实际影响最大的部分之一。

### 通用理解

- 系统提示词 > 全局提示词 > rules > 当前对话
- 不同工具对“前台文件”“后台文件”“历史摘要”“自动检索结果”的注入策略不同
- 所谓上下文大小，不只是模型理论上限，还包括产品层的压缩策略、检索策略和配额规则

### 一些实用观察

- **Codex**：支持调上下文窗口和自动压缩阈值
- **Claude Code**：`/context` 和 `/compact` 对排查上下文问题很有帮助
- **Gemini CLI**：`/status session`、`/compress` 更偏命令式管理
- **Cursor / Trae / VSCode 系工具**：很多时候上下文能力与 IDE 前后台文件、RAG 检索和编辑器集成强相关

例如 Codex 可在配置里调整：

```toml
model_context_window=1000000
model_auto_compact_token_limit=900000
```

___

## 自备 API Key 与中转

### 自备 API Key

不同工具对“自备 key”支持度差异很大。有的原生支持，有的只支持部分模型，有的需要会员资格，有的虽然能配但路径比较绕。

以 Claude Code 为例，常见做法是通过环境变量写入：

```powershell
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "你的 base_url", "User")
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "你的 api_key", "User")
```

或者：

```powershell
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "你的 base_url", "User")
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "你的 auth_token", "User")
```

写入后通常需要重新打开终端，环境变量才会生效。

### 中转与反代

这部分风险最高，也最容易过时。不同厂商对代理、中转、OAuth、反向代理的容忍度差异很大，而且会不断调整。这里不写死“谁一定没事、谁一定封号”，更稳妥的说法是：

- 涉及中转、反代、共享账号时，默认按高风险对待
- 优先看官方 ToS、账号政策和最新用户反馈
- 如果是长期主力工作流，尽量避免依赖高风险链路

___

## 无人值守 / 自动同意

“能不能尽量少弹权限确认”是很多人很关心的一点。

- **Trae**：常见说法是有 yolo 类模式
- **Gemini CLI**：常见用法是 `gemini -yolo`
- **Claude Code**：可以配置更激进的权限模式
- **Codex / OpenCode 一类 CLI**：也普遍支持更偏自动化的工作模式

以 Claude Code 为例，常见配置是：

```json
"claudeCode.initialPermissionMode": "bypassPermissions",
"claudeCode.allowDangerouslySkipPermissions": true
```

但这类设置会显著扩大工具权限范围，除了改文件，也可能放开命令执行、网络访问等能力。生产环境或高价值仓库里要谨慎使用。

___

## 模式、模型与思考强度

很多工具都开始把“聊天模式”拆得更细：问答、编辑、Agent、Plan、Debug、Architect、Review、Orchestrator 等，本质上是在控制两件事：

1. 允许模型做什么
2. 强迫模型怎么思考

### 典型模式差异

- **Codex**：默认更偏直接动手，也提供 Plan 模式和不同思考强度
- **Claude Code**：`Plan`、`Ask before edit`、`Bypass permissions` 区分很清楚
- **Lingma / Kilo**：常把 Ask / Edit / Agent / Debug / Architect 等拆得更细
- **OpenCode CLI**：`Build` 偏执行，`Plan` 偏只读分析

如果是复杂任务，Plan 模式的价值不只是“更安全”，更重要的是它会强迫模型先建模、先拆解、再行动。

___

## RAG、检索与补全

### RAG

- **Cursor / Trae / Lingma / Kilo Code 插件**：通常会更强调 IDE 内的 RAG 或索引能力
- **Codex / Antigravity / Claude Code / OpenCode**：很多时候更接近“搜索 + 文件读取 + 工具调用”的路线，常见是直接用 `rg` 一类检索能力

### 自动补全

- **Cursor / Antigravity / Trae / Lingma**：通常都有比较强的补全体验
- **Codex 插件 / CodeBuddy 一类插件**：补全不是绝对核心卖点时，体验可能与 IDE 原生补全不同

___

## 撤销、历史和中间文件

### 撤销

最稳的撤销方式始终还是编辑器自身的 `Ctrl+Z`，前提是文件真实落盘并且当前编辑器还保留了历史。

至于“让 AI 撤销上一步”，本质往往不是严格意义上的 undo，而是再做一次反向修改，因此可靠性参差不齐。

### 中间文件

有些工具会显式落地 `task.md`、`implementation_plan.md` 之类的中间文件；也有些工具更偏“都藏在会话里”。

如果你重视过程可追溯性，那么能落地中间文件的工具通常更友好。

### 聊天记录与 Artifact

这部分非常依赖具体产品实现，而且很容易随着版本变化失准。更适合在排查问题时单独写专题，而不适合堆在总对比文里写得过细。

___

## `settings.json` 与 `keybindings.json` 的同步

这一部分对 VSCode 系工具特别实用。

### 基本思路

- 把一个 IDE 的 `settings.json` / `keybindings.json` 映射到另一个 IDE
- 用一份主配置去驱动多个同类编辑器

例如：

```text
把 /AppData/Roaming/Antigravity/User/settings.json 和 keybindings.json
映射到 /AppData/Roaming/Cursor/User/
```

```text
把 /AppData/Roaming/Antigravity/User/settings.json 和 keybindings.json
映射到 /AppData/Roaming/Code/User/
```

```text
把 /AppData/Roaming/Antigravity/User/settings.json 和 keybindings.json
映射到 /AppData/Roaming/Trae CN/User/
```

### 需要注意的点

- 不同 IDE 的专有设置项名称往往不同，所以共享同一份 JSON 时不一定会互相冲突
- 但有些产品仍会把少量配置写进数据库或 `globalStorage`，这部分无法只靠 JSON 映射解决
- `workspace/settings.json` 不适合拿来做跨 workspace 的长期同步，因为换项目后就失效了

___

## 最后总结

如果只想抓重点，这篇文章最值得记住的是四件事：

1. rules 和 skills 的目录结构看起来相似，但触发机制差异很大
2. Git 忽略、AI 检索范围、RAG 索引范围，不一定是同一套边界
3. 真正影响使用体验的，不只是模型本身，还有上下文注入、压缩、权限模式和 IDE 集成
4. 价格、额度、封号风险、会员权益这些信息变化很快，适合单独查，不适合死记旧表
