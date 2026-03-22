---
title: 我当前在 OpenCode 使用的全局 Skills 体系说明与下载
date: 2026-03-23 00:40:00
updated: 2026-03-23 00:40:00
tags: [OpenCode, Skills, AI工具, 工作流]
categories: [AI工具配置]
description: 记录我当前在 OpenCode 中使用的全局 skills 体系、分类作用与压缩包下载方式。
cover: /img/cover/cover40.webp
top_img: /img/cover/cover40.webp
---

这篇文章记录我当前在 OpenCode 中使用的全局 skills 体系：它们分别负责什么、适合在什么场景下调用、哪些是主技能、哪些是辅助技能，以及我为什么这样组织。

## 下载

当前导出的 OpenCode 全局 skills 压缩包：

- [下载 opencode-global-skills.zip](/assets/downloads/opencode-global-skills.zip)

> 说明：压缩包里排除了 `.git` 元数据目录，保留的是当前实际使用的全局 skills 内容。

___

## 先说结论：我怎么理解全局 Skills

我现在对全局 skills 的理解，不再是“装得越多越好”，而是更接近一套分层工具箱：

1. **流程控制类**：决定 AI 该怎么工作
2. **通用能力类**：处理文档、前端、GitHub、文件、记忆等高频任务
3. **领域专项类**：处理科研、Unity、Feishu、文档格式等专业场景
4. **辅助增强类**：补足某些主技能没有覆盖到的细粒度工作流

这样组织的好处是：

- 平时高频任务有稳定入口
- 遇到复杂任务时能自动切换到更专业的 skill
- 不容易因为目录太乱而把重复 skill、弱化 skill、容器目录也当成主技能使用

___

## 一、流程控制类：决定 AI 怎么工作

这一类是我最重视的，因为它们不是解决某一个业务问题，而是决定整个代理在面对任务时的行为方式。

### `superpowers`

这是工作流总控层。里面包含了很多关键子技能，比如：

- `using-superpowers`
- `brainstorming`
- `writing-plans`
- `verification-before-completion`
- `systematic-debugging`
- `test-driven-development`

它们分别负责：

- 在任务开始前检查是否该启用 skill
- 在写代码前先做方案与拆解
- 在完成前强制做验证
- 出现 bug 时优先走系统化排查，而不是盲改

如果把所有全局 skill 比作一个团队，这一层更像“项目经理 + 研发流程规范”。

### `memory` / `distill-memory` / `search-memory`

这一组负责“记住”和“想起来”。

- `memory`：完整记忆系统，适合做长期上下文沉淀
- `distill-memory`：把关键结论压缩成可复用记忆
- `search-memory`：当任务与历史内容有关时主动回忆

这组 skill 的价值不在于“能不能存”，而在于减少反复解释背景、减少上下文丢失后的重复劳动。

___

## 二、通用能力类：高频任务的主技能

这一层是最常用的主力技能区，覆盖大多数实际工作流。

### 文档与内容协作

- `doc-coauthoring`：适合一起写 spec、PRD、设计文档、决策文档
- `docx`：处理 Word 文档
- `pdf`：处理 PDF 阅读、拆分、提取、表单
- `pptx`：处理演示文稿
- `xlsx`：处理表格、数据分析、公式与格式
- `internal-comms`：写团队内部汇报、FAQ、周报、项目更新
- `email-composer`：写正式邮件，适合对外或半正式沟通

这里我的使用原则很简单：

- 要写“结构化说明文”时，用 `doc-coauthoring`
- 要操作具体文件格式时，用 `docx` / `pdf` / `pptx` / `xlsx`
- 要做组织沟通时，用 `internal-comms` 或 `email-composer`

### 前端与设计

- `frontend-design`：做网页、页面、组件、界面设计
- `web-artifacts-builder`：做复杂 HTML artifact
- `canvas-design`：做静态视觉作品、海报、图形设计
- `algorithmic-art`：做生成式视觉作品
- `theme-factory`：给已有作品套主题
- `slack-gif-creator`：做适合 Slack 的 GIF

这层里面：

- `frontend-design` 更偏“产品界面”
- `canvas-design` 更偏“静态视觉成品”
- `web-artifacts-builder` 更偏“复杂交互 artifact”

### 开发协作与代码相关

- `github`：查 PR、Issue、状态、评论等
- `filesystem`：文件目录分析与批量处理
- `shell`：写稳健 shell 脚本
- `mcp-builder`：设计或实现 MCP server
- `skill-creator`：写新的 skill
- `webapp-testing`：本地 web 应用测试
- `git-commit-helper`：辅助生成更清晰的 commit message

这组可以理解为“日常开发基础设施技能”。

___

## 三、集成与平台类：让 AI 接到更多外部能力

这组 skill 主要作用不是输出内容，而是对接生态和平台。

### Feishu 系列

- `feishu-doc`
- `feishu-drive`
- `feishu-perm`
- `feishu-wiki`

适合处理飞书文档、云盘、权限和知识库。

### Unity 系列

- `unity-skills`
- `unity-ui`
- `unity-scene`
- `unity-script`
- `unity-editor`
- 以及大量 `unity-*` 子技能

这套 skill 比较像一整套 Unity 操作系统，覆盖场景、材质、脚本、组件、灯光、测试、Timeline、Profiler 等。

### 其他平台与专项集成

- `obsidian`：处理笔记库
- `github`：GitHub 生态操作
- `weather`：天气
- `blogwatcher`：博客/RSS 监控
- `find-skills`：帮你反查有没有可用技能

___

## 四、科研与专业扩展类：把 AI 变成细分领域工具箱

这是我这次专门补进来的重点区域之一。

### `academic-research`

这是学术检索主入口，适合：

- 找论文
- 按主题、作者、DOI 搜索
- 看引用链
- 做文献综述初步整理

它解决的是“先把相关论文搜到”的问题。

### `scientific-thinking` 及子技能

这是“科研思考工作流层”。我现在保留了这些辅助 skill：

- `scientific-brainstorming`
- `hypothesis-generation`
- `exploratory-data-analysis`
- `statistical-analysis`
- `scientific-critical-thinking`
- `scientific-writing`
- `scientific-visualization`
- `literature-review`
- `peer-review`
- `scholar-evaluation`

这些技能的价值在于：它们不是单纯帮你“查文献”，而是把科研任务拆成了更细的步骤：

- 怎么提出假设
- 怎么探索数据
- 怎么做统计判断
- 怎么写科研文本
- 怎么做学术评价

### `scientific-databases`

这一层负责接具体数据库，例如：

- `geo-database`
- `gene-database`
- `uspto-database`
- `zinc-database`

适合做更垂直的数据库访问，而不是停留在通用论文搜索。

### `scientific-integrations`

这一层负责接实验和科研平台：

- `benchling-integration`
- `dnanexus-integration`
- `labarchive-integration`
- `latchbio-integration`
- `omero-integration`
- `opentrons-integration`
- `protocolsio-integration`

这些技能对普通开发者未必常用，但对于实验流程、科研数据平台、自动化实验等场景有价值。

### `scientific-packages`

这是一组“包级 skill”，用于补足特定 Python 科学计算或科研包的使用经验，比如：

- `anndata`
- `biopython`
- `transformers`
- `torch_geometric`
- `umap-learn`
- `vaex`
- `zarr-python`
- `dask`
- `astropy`
- `neurokit2`

这些 skill 更像“细分技术插件”，当任务真的涉及到对应包时才会有明显价值。

___

## 五、我当前保留这些全局 Skills 的原则

这次整理之后，我的原则变成了下面这套：

### 1. 主技能优先，弱化重复入口

例如：

- 保留 `web-artifacts-builder`，不再保留重复的 `artifacts-builder`
- 保留 `xlsx`，不再用弱化版 `excel-analysis` 作为主入口

### 2. 容器目录不当主技能

像这些目录：

- `development`
- `document-processing`
- `creative-design`
- `enterprise-communication`

它们本身更像技能包，不适合当成顶层主入口。我已经把这些纯容器目录清理掉，保留真正可调用的 skill。

### 3. 允许保留有价值的辅助 skill

比如：

- `pdf-processing-pro`
- `email-composer`
- `git-commit-helper`
- `distill-memory`
- `search-memory`

它们和主技能有一定重叠，但能补充更具体的工作流，所以我保留了。

### 4. 专业领域技能按需常驻

科研类 skill 数量很多，但如果你明确知道自己会涉及科研、数据库、实验平台、统计分析，这类技能保留在全局是值得的。

___

## 六、适合参考的全局 Skills 分组

如果你也想搭一套自己的全局 skill，我建议至少按下面这几个大类来组织：

- **流程控制**：`superpowers`、`memory`
- **文档处理**：`docx`、`pdf`、`pptx`、`xlsx`、`doc-coauthoring`
- **前端设计**：`frontend-design`、`web-artifacts-builder`、`canvas-design`
- **开发协作**：`github`、`filesystem`、`shell`、`mcp-builder`
- **平台集成**：`feishu-*`、`unity-*`、`obsidian`
- **专业扩展**：`academic-research`、`scientific-*`

这样做的优点是：后面再加 skill 时，你不会把目录越堆越乱，而是知道它应该归到哪一类。

___

## 结语

我现在更倾向于把全局 skills 当成“自己的 AI 开发环境配置”，而不是单纯的素材仓库。

真正有用的不是 skill 数量，而是：

- 是否有稳定的主入口
- 是否能减少重复技能
- 是否能在高频任务中自然命中
- 是否能在专业任务里提供真正的补强

如果你只是想快速复用一套可工作的 OpenCode 全局技能配置，可以直接下载我当前导出的压缩包：

- [下载 opencode-global-skills.zip](/assets/downloads/opencode-global-skills.zip)
