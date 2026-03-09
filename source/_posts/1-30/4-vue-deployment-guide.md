---
title: Vue 项目部署全记录：从 WSL 本地开发到 Docker 容器化与公网穿透
date: 2026-01-15 14:00:00
tags:
  - Vue
  - Docker
  - WSL
  - 部署
  - DevOps
categories:
  - 技术文档
cover: /img/cover/cover3.webp
top_img: /img/cover/cover3.webp
---

**环境**：Windows 11 + WSL 2 (Ubuntu 22.04/24.04)  
**项目**：Vue 2 + Vite (TodoList)

<!-- more -->

## 第一部分：基础环境搭建 (WSL)

无论采用哪种部署方式，首先需要确保 Linux 环境具备 Node.js 和 Git 能力。

### 1. 配置 Node.js (使用 NVM)

为了避免权限问题和灵活切换版本，使用 NVM (Node Version Manager) 安装 Node 20。

```bash
# 1. 安装 NVM (通过 Git 克隆，避开 curl 连接失败问题)
cd ~
git clone https://github.com/nvm-sh/nvm.git .nvm

# 2. 写入环境变量
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
source ~/.bashrc

# 3. 安装 Node 20
nvm install 20
nvm use 20
```

### 2. 获取项目与 Git 修复

解决 WSL 中 Git 可能遇到的 SSL 报错。

```bash
# 1. 修复 Git SSL 错误
git config --global http.sslBackend gnutls

# 2. 克隆项目
cd ~
git clone https://github.com/Austoin/Vue2-TodoList.git
cd Vue2-TodoList
```

---

## 第二部分：路径一 —— 本地原生运行 (Native Run)

这种方式适合开发阶段调试，直接在 Linux 终端运行项目。

### 1. 安装依赖与启动

```bash
# 清理可能存在的 Windows 平台缓存（重要习惯）
rm -rf node_modules package-lock.json

# 安装依赖
npm install

# 启动开发服务器 (默认端口通常是 5173)
npm run dev
```

---

## 第三部分：路径二 —— Docker 容器化部署 (推荐)

这种方式适合生产环境，解决"在我的机器上能跑"的依赖问题。

### 1. 解决 Docker WSL 连接

如果提示 `command 'docker' could not be found`：

1. 打开 Docker Desktop 设置 -> **Resources** -> **WSL Integration**。
2. 开启当前 Ubuntu 发行版的开关并重启。

### 2. 编写 Dockerfile (解决跨平台依赖坑)

**核心痛点**：本地 Windows 的 `node_modules` 包含特定平台的二进制文件，直接复制到 Linux 容器会报错 `vite: not found`。

**解决方案**：先复制，再强删，最后在容器内重装。

**Dockerfile 内容：**

```dockerfile
# 构建阶段
FROM node:lts-alpine as build-stage
WORKDIR /app
COPY . .
# 【核弹级修复】删除复制进来的本地依赖，保证环境纯净
RUN rm -rf node_modules package-lock.json
RUN npm install --registry=https://registry.npmmirror.com
RUN npm run build

# 运行阶段
FROM nginx:stable-alpine as production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 3. 构建与运行

```bash
# 1. 构建镜像 (使用 --no-cache 防止缓存旧的错误层)
docker build --no-cache -t my-vue-app .

# 2. 启动容器 (映射端口 8080 -> 80)
docker run -d -p 8080:80 --name vue-container my-vue-app
```

---

## 第四部分：公网穿透方案 (三选一)

将本地服务暴露给公网，以下是三种不同场景的方案。

### 方案 A：Cloudflare Tunnel (Docker 专用，最稳定)

适合长期运行，不需要本地安装客户端。

```bash
# 启动穿透容器，连接到 8080 端口
docker run -d --network host --name cf-tunnel cloudflare/cloudflared tunnel --url http://localhost:8080

# 查看日志获取链接
docker logs cf-tunnel
```

### 方案 B：Serveo (SSH 方式，无需安装，最快)

适合临时展示，利用 Linux 自带的 SSH 功能，无需下载任何东西。

**基本用法：**

```bash
# 格式：ssh -R 80:localhost:本地端口 serveo.net

# 如果是 Docker 容器 (8080端口)：
ssh -R 80:localhost:8080 serveo.net

# 如果是本地 npm run dev (5173端口)：
ssh -R 80:localhost:5173 serveo.net
```

- **注意**：第一次连接时会提示 `Are you sure...?`，输入 `yes` 回车。
- **自定义域名**（如果运气好没被占用）：`ssh -R mytodolist:80:localhost:8080 serveo.net`

### 方案 C：Tunnelto (需注册)

旧版简单，新版需要 Key，此处略过，作为备用。

---

## 第五部分：进程守护 (让服务在后台跑)

当你关闭终端窗口时，SSH (Serveo) 或 npm 进程通常会断开。使用 `nohup` 让它们在后台运行。

### 1. 后台运行 Serveo

```bash
# 将 Serveo 挂在后台，并将日志输出到 serveo.log
nohup ssh -R 80:localhost:8080 serveo.net > serveo.log 2>&1 &

# 查看生成的公网链接
cat serveo.log
```

### 2. 关闭后台进程

由于没有窗口了，需要手动查找并杀掉进程。

```bash
# 1. 查找 ssh 进程的 PID
ps aux | grep ssh

# 2. 杀掉进程 (假设 PID 是 12345)
kill 12345
```

---

## 总结：常用命令速查表

| 操作 | 命令 | 备注 |
|------|------|------|
| **构建镜像** | `docker build --no-cache -t <名字> .` | 加上 no-cache 避免缓存坑 |
| **启动容器** | `docker run -d -p 8080:80 --name <名字> <镜像名>` | 启动服务 |
| **CF 穿透** | `docker run ... cloudflare/cloudflared ...` | 稳定方案 |
| **Serveo 穿透** | `ssh -R 80:localhost:8080 serveo.net` | **免安装、极速方案** |
| **查看 Docker** | `docker ps` | 查看正在运行的容器 |
| **查看日志** | `docker logs <容器ID>` | 排查问题 |
