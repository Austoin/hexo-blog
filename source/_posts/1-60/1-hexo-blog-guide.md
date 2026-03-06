---
title: Hexo 博客搭建与创作全指南
date: 2025-06-08 10:00:00
updated: 2025-06-08 10:00:00
tags: [Hexo, 博客]
categories: [技术文档]
description: 从环境配置到文章发布的完整 Hexo 博客搭建指南，包含常见问题解决方案
cover: /img/cover/cover1.webp
top_img: /img/cover/cover1.webp
---

# Hexo 博客搭建与创作全指南

## 一、 核心问题诊断

1. **路径兼容性**：Windows 用户名 username 带有单引号，导致 npm 默认 C 盘缓存路径解析崩溃。
2. **工具 Bug**：`npm 8.19.4` 逻辑漏洞导致 `matches of null` 报错。
3. **版本冲突 (ESM)**：`Hexo 8.x` 的部分底层依赖在 Windows 下报 `ERR_REQUIRE_ESM`。

---

## 二、 环境修复 (避坑指南)

### 1. 迁移 npm 路径 (避开 C 盘单引号)

```powershell
mkdir F:\Hexo\npm_global
mkdir F:\Hexo\npm_cache
npm config set prefix "F:\Hexo\npm_global"
npm config set cache "F:\Hexo\npm_cache"
```

### 2. Node 版本管理 (nvm)

使用 Node 20 以确保 npm 10.x 的稳定性：

```powershell
nvm install 20.18.0
nvm use 20.18.0
```

---

## 三、 项目核心配置 (`package.json`)

必须锁定 Hexo 7.3 并使用 `overrides` 修复子依赖冲突：

```json
{
  "dependencies": {
    "hexo": "^7.3.0",
    "hexo-deployer-git": "^4.0.0",
    "hexo-server": "^3.0.0",
    "hexo-renderer-pug": "^3.0.0",
    "hexo-renderer-stylus": "^3.0.0"
  },
  "overrides": {
    "strip-ansi": "6.0.1",
    "wrap-ansi": "7.0.0"
  }
}
```

---

## 四、 文章创作流程 (Daily Workflow)

### 1. 新建文章

```powershell
hexo new post "文章标题"
```

文件保存在：`source/_posts/文章标题.md`

### 2. 编写 Front-matter (安知鱼主题特色)

编辑 `.md` 文件顶部配置，推荐模板：

```markdown
---
title: 文章标题
date: 2026-02-24 15:00:00
updated: 2026-02-24 15:00:00
tags: [标签1, 标签2]
categories: [分类]
cover: /img/cover1.png       # 首页封面图
top_img: /img/top1.png       # 文章顶部大图
description: 这是创建blog的logs内容         #这是文章的简短摘要
ai: 这是本文的 AI 助手摘要内容（安知鱼特色）
sticky: 1                   # 数字越大，置顶等级越高
---
```

### 3. 图片处理

- 将图片放入 `source/img/` 或文章同名文件夹。
- 引用语法：`![描述](/img/xxx.jpg)`。

---

## 五、 发布与部署

### 1. 本地预览

```powershell
hexo clean ; hexo s
```

访问：`http://localhost:4000`

### 2. 部署到 GitHub

**注意：仓库名拼写为 Austoin (u 在 s 前)**

```powershell
hexo clean ; hexo g -d
```

部署地址：`https://Austoin.github.io`

---

## 六、 常用指令清单 (Cheat Sheet)

| 目的          | 指令                                 |
|:----------- |:---------------------------------- |
| **新建文章**    | `hexo new post "标题"`               |
| **本地开发预览**  | `hexo clean ; hexo s`              |
| **一键部署上线**  | `hexo clean ; hexo g -d`           |
| **切换环境版本**  | `nvm use 20.18.0`                  |
| **清理并重装依赖** | `rm -r node_modules ; npm install` |

---

## 七、 安知鱼主题维护建议

1. **配置文件**：建议在根目录使用 `_config.anzhiyu.yml` 管理主题配置，避免直接修改 `themes` 目录。
2. **语言设置**：在根目录 `_config.yml` 中设置 `language: zh-CN`。
3. **依赖插件**：如需搜索功能，请安装 `npm install hexo-generator-searchdb --save`。

---

*Last Updated: 2025-06-08*
*Status: 环境稳定，已成功部署*
