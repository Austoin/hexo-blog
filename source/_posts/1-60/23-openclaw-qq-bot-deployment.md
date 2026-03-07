---
title: 腾讯云部署 OpenClaw QQ 机器人：中转 API + Web UI 可视化完整指南
date: 2026-03-07 22:00:00
updated: 2026-03-07 22:00:00
tags: [OpenClaw, QQ机器人]
categories: [技术文档]
description: 详细讲解如何在腾讯云服务器上部署 OpenClaw QQ 机器人，包括服务器配置、中转 API 设置、机器人创建以及 Web UI 可视化管理的完整流程
cover: /img/cover/cover23.webp
top_img: /img/cover/cover23.webp
---

## 前言

本文将详细介绍如何在腾讯云服务器上部署 OpenClaw，并将其配置为 QQ 机器人，同时实现 Web UI 可视化管理。

## 一、服务器准备

### 1.1 购买云服务器

云服务部署首先需要一台服务器，购买时有两种选择：

- **方式一**：购买时直接选择 OpenClaw 作为系统镜像实例
- **方式二**：使用现有服务器，重装系统为 OpenClaw 镜像

### 1.2 检查端口配置

确保服务器的 **18789 端口** 已放通，这是 OpenClaw Web UI 的默认端口。

在腾讯云控制台的安全组规则中添加：
- 协议：TCP
- 端口：18789
- 来源：0.0.0.0/0（或根据需要限制 IP）

## 二、配置 OpenClaw

### 2.1 配置中转 API

OpenClaw 支持多种 AI 服务商，这里以中转 API 为例进行配置。

创建配置文件，输入以下内容：

```json
{
  "provider": "openai",
  "base_url": "https://elysiver.h-e.top/v1",
  "api": "openai-completions",
  "api_key": "sk-xxx",
  "model": {
    "id": "gpt-5.2-low",
    "name": "gpt-5.2-low"
  }
}
```

**配置说明：**
- `provider`: 服务提供商类型
- `base_url`: 中转 API 的基础 URL
- `api_key`: 你的 API 密钥（需要替换为实际密钥）
- `model`: 使用的模型 ID 和名称

### 2.2 测试配置

在服务器终端运行以下命令，测试 OpenClaw 是否正常工作：

```bash
openclaw tui
```

如果能正常进入对话界面并得到回复，说明配置成功。

**参考教程：** [腾讯云 OpenClaw 配置指南](https://cloud.tencent.com/developer/article/2624003)

## 三、创建 QQ 机器人

### 3.1 注册机器人

访问 QQ 机器人官方平台：https://q.qq.com/qqbot/openclaw/index.html

在平台上创建一个新的机器人，获取以下信息：
- Bot ID
- Bot Token
- Bot Secret

### 3.2 配置机器人信息

将获取到的机器人信息输入到云服务器的 OpenClaw 配置中。

![机器人配置界面](/img/posts/23-openclaw/1.webp)

### 3.3 测试机器人

配置完成后，直接在 QQ 中 @ 你的机器人并发送消息，测试是否能正常回复。

![QQ 机器人测试](/img/posts/23-openclaw/2.webp)

**参考教程：** [QQ 机器人接入指南](https://cloud.tencent.com/developer/article/2626045)

## 四、Web UI 可视化管理

如果你熟悉命令行操作，这部分可以跳过。Web UI 提供了更友好的可视化管理界面。

### 4.1 建立 SSH 隧道

Web UI 通过本地终端与云服务器的 18789 端口连接实现。

在本地终端（Windows PowerShell 或 CMD）中输入：

```bash
ssh -N -L 18789:127.0.0.1:18789 root@服务器公网IP地址
```

**命令说明：**
- `-N`: 不执行远程命令，仅建立端口转发
- `-L`: 本地端口转发
- `18789:127.0.0.1:18789`: 将本地 18789 端口映射到服务器的 18789 端口
- `root@服务器公网IP`: 服务器登录信息

输入密码后，**保持终端窗口打开**，不要关闭。

### 4.2 访问 Web UI

在浏览器中访问：

```
http://localhost:18789/chat?session=agent%3Amain%3Amain
```

### 4.3 获取并输入 Token

首次访问需要输入网关令牌（Token）进行身份验证。

在云服务器终端执行以下命令获取 Token：

```bash
cat /root/.openclaw/openclaw.json | grep -A2 token
```

![获取 Token](/img/posts/23-openclaw/3.webp)

将获取到的 Token 复制并粘贴到 Web UI 的"网关令牌"输入框中。

![输入 Token](/img/posts/23-openclaw/4.webp)

### 4.4 开始使用

Token 验证成功后，即可在 Web UI 中进行可视化对话和管理。

![Web UI 对话界面](/img/posts/23-openclaw/5.webp)

**参考教程：** [OpenClaw Web UI 使用指南](https://cloud.tencent.com/developer/article/2627309)

## 五、常见问题

### 5.1 端口无法访问

- 检查服务器安全组是否开放 18789 端口
- 确认 SSH 隧道是否正常建立
- 检查本地防火墙设置

### 5.2 机器人无响应

- 验证 API 密钥是否正确
- 检查中转 API 服务是否可用
- 查看 OpenClaw 日志排查错误

### 5.3 Token 验证失败

- 确保复制的 Token 完整无误
- 重新获取 Token 并尝试
- 检查 OpenClaw 配置文件权限

## 总结

通过本文的步骤，你已经成功在腾讯云上部署了 OpenClaw QQ 机器人，并配置了 Web UI 可视化管理。这套方案结合了云服务的稳定性和可视化界面的便捷性，适合快速搭建和管理 AI 机器人服务。

## 进阶应用

到这里，你已经完成了 OpenClaw 的部署。现在你可以给它授权账号密码等信息，然后上课摸鱼让它一直给你打工了。

**可能的应用场景：**
- 帮你在网店自动回复客户、处理订单
- 观察市场数据、分析股票走势
- 远程执行代码、开发小工具
- 自动修复 Bug、生成代码片段
- 你有想法一般都办得到

**成本提醒：**

OpenClaw 的 Token 消耗是比较大的，需要注意成本控制。以我的使用经验为例：
- 模型：GPT-5.2（倍率 0.2）
- 消耗：30 条对话约 10 美元
- 建议：合理设置使用频率和对话长度，避免不必要的消耗

最基础的应用当然是远程执行代码做些小玩意或修 Bug 了，但只要你有创意，OpenClaw 能做的远不止这些。

## 参考资源

- [OpenClaw 官方文档](https://cloud.tencent.com/developer/article/2624003)
- [QQ 机器人平台](https://q.qq.com/qqbot/openclaw/index.html)
- [我的博客](https://austoin.github.io)
