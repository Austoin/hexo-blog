---
title: Golang 即时通信系统：9 个版本迭代详解（含完整代码）
date: 2026-03-09 10:30:00
updated: 2026-03-09 10:30:00
tags: [golang, tcp, 项目实战]
categories: [后端开发]
description: 基于 TCP 长连接，从版本一到版本九完整实现 Golang IM 系统。每个版本都给出设计说明和代码片段，文末附项目目录结构与完整可运行代码。
cover: /img/cover/cover27.webp
top_img: /img/cover/cover27.webp
---

# Golang 即时通信系统 9 个版本迭代

本文按照项目真实迭代顺序讲解：

- 版本一：基础 TCP Server
- 版本二：用户上线
- 版本三：消息广播
- 版本四：用户业务封装
- 版本五：在线用户查询
- 版本六：修改用户名
- 版本七：超时强踢
- 版本八：私聊
- 版本九：客户端实现

每个版本都包含两部分：

1. 改动目标（为什么改）
2. 关键代码（怎么改）

---

## 先看懂架构图：系统分层与数据流

这个项目的架构图可以简化成 4 层：

1. 客户端层：`client.go` 负责菜单、命令输入、消息展示。
2. 连接层：基于 TCP 长连接，每个客户端和服务端之间都有一个 `conn`。
3. 服务调度层：`server.go` 负责监听端口、接入连接、广播分发、超时控制。
4. 用户业务层：`user.go` 负责解析命令并执行业务（`who`、`rename|`、`to|`）。

可以把整条消息链路理解为：

`Client 输入 -> conn.Write -> Server.Handler 读取 -> User.DoMessage 解析 -> 广播/私聊 -> 目标用户 conn.Write 输出`

为什么要这样分层：

- `server.go` 专注“调度连接”，避免和具体业务耦合。
- `user.go` 专注“处理命令”，后续扩展指令更容易。
- `client.go` 专注“交互体验”，和服务端实现解耦。

---

## 网络基础扫盲：`net` 和 `conn` 是什么

### 1) `net` 是什么

`net` 是 Go 标准库的网络包，TCP 聊天室最常见用法是：

- `net.Listen("tcp", "127.0.0.1:8888")`：服务端开启监听。
- `listener.Accept()`：阻塞等待一个新客户端连接。
- `net.Dial("tcp", "127.0.0.1:8888")`：客户端主动连接服务端。

### 2) `conn` 是什么

`conn` 是 `net.Conn` 接口，代表“一条双向连接”。你可以把它当成电话线：

- `conn.Read([]byte)`：从连接里读对方发来的字节。
- `conn.Write([]byte)`：往连接里写字节给对方。
- `conn.Close()`：关闭这条连接。

### 3) 最小通信示例（帮助你建立直觉）

服务端：

```go
listener, _ := net.Listen("tcp", "127.0.0.1:8888")
conn, _ := listener.Accept()
buf := make([]byte, 1024)
n, _ := conn.Read(buf)
fmt.Println("收到:", string(buf[:n]))
conn.Write([]byte("收到你的消息了\n"))
```

客户端：

```go
conn, _ := net.Dial("tcp", "127.0.0.1:8888")
conn.Write([]byte("你好，服务端\n"))
buf := make([]byte, 1024)
n, _ := conn.Read(buf)
fmt.Println("服务端回复:", string(buf[:n]))
```

在 IM 项目里，本质上就是把“1 个 conn 的收发”扩展为“多个 conn 并发收发 + 命令分发”。

---

## 代码前必须知道的 5 个概念

1. `goroutine`：每个连接通常单独开协程处理，不会互相阻塞。
2. `channel`：协程之间传消息，广播时通过全局消息通道分发。
3. `OnlineMap`：在线用户表，key 一般是用户名，value 是 `*User`。
4. 命令协议：约定文本格式，例如 `who`、`rename|张三`、`to|李四|你好`。
5. 连接生命周期：连接建立 -> 上线 -> 收发消息 -> 下线或超时关闭。

带着这 5 个概念再看版本一到版本九，代码会顺很多。

## 版本一：构建基础 Server

### 改动目标

先把最小可运行版本搭起来：

- 定义 `Server` 结构体
- 启动 TCP 监听
- 接受连接并交给 `Handler`

### 版本一结构图

![版本一结构图](/img/posts/27-golang-im/version1-structure.webp)

图中重点可以先抓 3 条线：

- `main.go` 只做入口，创建并启动 `Server`。
- `server.go` 负责监听端口、接收连接、把连接交给 `Handler`。
- 本版本 `Handler` 先做占位，目标是先打通“能接入连接”的最小闭环。

### 关键代码

```go
// server/main.go
package main

func main() {
    server := NewServer("127.0.0.1", 8888)
    server.Start()
}
```

```go
// server/server.go
type Server struct {
    Ip   string
    Port int
}

func NewServer(ip string, port int) *Server {
    return &Server{Ip: ip, Port: port}
}

func (s *Server) Handler(conn net.Conn) {
    // 版本一先只做连接占位，后续版本扩展
    conn.Close()
}

func (s *Server) Start() {
    address := fmt.Sprintf("%s:%d", s.Ip, s.Port)
    listener, err := net.Listen("tcp", address)
    if err != nil {
        fmt.Println("net.Listen err:", err)
        return
    }
    defer listener.Close()

    for {
        conn, err := listener.Accept()
        if err != nil {
            fmt.Println("listener.Accept err:", err)
            continue
        }
        go s.Handler(conn)
    }
}
```

---

## 版本二：用户上线功能

### 改动目标

引入用户概念，维护在线用户集合，并能广播“某用户上线”。

### 版本二结构图

![版本二结构图](/img/posts/27-golang-im/version2-structure.webp)

版本二比版本一多了“用户状态管理”主线：

- `User` 被正式引入，连接不再只是裸 `conn`。
- `OnlineMap` 记录在线用户，`mapLock` 保证并发安全。
- `Message` 作为广播通道，后续版本会扩展成完整广播机制。

### 关键代码

```go
// server/server.go
type Server struct {
    Ip        string
    Port      int
    OnlineMap map[string]*User
    mapLock   sync.RWMutex
    Message   chan string
}

func NewServer(ip string, port int) *Server {
    return &Server{
        Ip:        ip,
        Port:      port,
        OnlineMap: make(map[string]*User),
        Message:   make(chan string),
    }
}

func (s *Server) BroadCast(user *User, msg string) {
    sendMsg := fmt.Sprintf("[%s]%s: %s", user.Addr, user.Name, msg)
    s.Message <- sendMsg
}
```

```go
// server/user.go
type User struct {
    Name   string
    Addr   string
    C      chan string
    conn   net.Conn
    server *Server
}

func NewUser(conn net.Conn, server *Server) *User {
    userAddr := conn.RemoteAddr().String()
    user := &User{
        Name:   userAddr,
        Addr:   userAddr,
        C:      make(chan string),
        conn:   conn,
        server: server,
    }
    go user.ListenMessage()
    return user
}

func (u *User) Online() {
    u.server.mapLock.Lock()
    u.server.OnlineMap[u.Name] = u
    u.server.mapLock.Unlock()
    u.server.BroadCast(u, "已上线")
}
```

---

## 版本三：用户消息广播机制

### 改动目标

让每个用户发言都能被全体在线用户收到。

### 关键代码

```go
// server/server.go
func (s *Server) ListenMessage() {
    for {
        msg := <-s.Message
        s.mapLock.RLock()
        for _, user := range s.OnlineMap {
            user.C <- msg
        }
        s.mapLock.RUnlock()
    }
}
```

```go
// server/server.go
func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    buf := make([]byte, 4096)
    for {
        n, err := conn.Read(buf)
        if n == 0 {
            user.Offline()
            return
        }
        if err != nil {
            fmt.Println("conn.Read err:", err)
            return
        }
        msg := strings.TrimSpace(string(buf[:n]))
        s.BroadCast(user, msg)
    }
}
```

---

## 版本四：用户业务层封装

### 改动目标

把“解析消息、执行业务”收敛到 `User`，`Server.Handler` 只负责生命周期调度。

### 关键代码

```go
// server/user.go
func (u *User) Offline() {
    u.server.mapLock.Lock()
    delete(u.server.OnlineMap, u.Name)
    u.server.mapLock.Unlock()
    u.server.BroadCast(u, "下线")
}

func (u *User) SendMsg(msg string) {
    _, _ = u.conn.Write([]byte(msg))
}

func (u *User) DoMessage(msg string) {
    // 版本四先做默认广播，后续版本加命令分支
    u.server.BroadCast(u, msg)
}
```

```go
// server/server.go
func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    buf := make([]byte, 4096)
    for {
        n, err := conn.Read(buf)
        if n == 0 {
            user.Offline()
            return
        }
        if err != nil {
            fmt.Println("conn.Read err:", err)
            return
        }
        msg := strings.TrimSpace(string(buf[:n]))
        user.DoMessage(msg)
    }
}
```

---

## 版本五：在线用户查询（`who`）

### 改动目标

支持客户端发送 `who`，查看当前在线用户列表。

### 关键代码

```go
// server/user.go
func (u *User) DoMessage(msg string) {
    if msg == "who" {
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            onlineMsg := "[" + user.Addr + "]" + user.Name + ": 在线\n"
            u.SendMsg(onlineMsg)
        }
        u.server.mapLock.RUnlock()
        return
    }

    u.server.BroadCast(u, msg)
}
```

---

## 版本六：修改用户名（`rename|新名字`）

### 改动目标

支持动态改名，并处理用户名冲突。

### 关键代码

```go
// server/user.go
func (u *User) DoMessage(msg string) {
    if msg == "who" {
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            onlineMsg := "[" + user.Addr + "]" + user.Name + ": 在线\n"
            u.SendMsg(onlineMsg)
        }
        u.server.mapLock.RUnlock()
        return
    }

    if strings.HasPrefix(msg, "rename|") {
        parts := strings.SplitN(msg, "|", 2)
        if len(parts) != 2 || parts[1] == "" {
            u.SendMsg("格式错误，请使用 rename|新用户名\n")
            return
        }
        newName := parts[1]

        u.server.mapLock.Lock()
        if _, ok := u.server.OnlineMap[newName]; ok {
            u.server.mapLock.Unlock()
            u.SendMsg("当前用户名已被使用\n")
            return
        }
        delete(u.server.OnlineMap, u.Name)
        u.server.OnlineMap[newName] = u
        u.Name = newName
        u.server.mapLock.Unlock()

        u.SendMsg("用户名修改成功: " + u.Name + "\n")
        return
    }

    u.server.BroadCast(u, msg)
}
```

---

## 版本七：超时强踢

### 改动目标

用户长时间无输入视为不活跃，服务端主动断开连接。

### 关键代码

```go
// server/server.go
func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    isLive := make(chan struct{})

    go func() {
        buf := make([]byte, 4096)
        for {
            n, err := conn.Read(buf)
            if n == 0 {
                user.Offline()
                return
            }
            if err != nil {
                fmt.Println("conn.Read err:", err)
                return
            }

            msg := strings.TrimSpace(string(buf[:n]))
            user.DoMessage(msg)
            isLive <- struct{}{}
        }
    }()

    timer := time.NewTimer(300 * time.Second)
    defer timer.Stop()

    for {
        select {
        case <-isLive:
            if !timer.Stop() {
                <-timer.C
            }
            timer.Reset(300 * time.Second)
        case <-timer.C:
            user.SendMsg("你被踢了\n")
            close(user.C)
            _ = conn.Close()
            return
        }
    }
}
```

---

## 版本八：私聊（`to|用户名|内容`）

### 改动目标

支持点对点消息，不走全局广播。

### 关键代码

```go
// server/user.go
func (u *User) DoMessage(msg string) {
    if msg == "who" {
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            onlineMsg := "[" + user.Addr + "]" + user.Name + ": 在线\n"
            u.SendMsg(onlineMsg)
        }
        u.server.mapLock.RUnlock()
        return
    }

    if strings.HasPrefix(msg, "rename|") {
        parts := strings.SplitN(msg, "|", 2)
        if len(parts) != 2 || parts[1] == "" {
            u.SendMsg("格式错误，请使用 rename|新用户名\n")
            return
        }
        newName := parts[1]

        u.server.mapLock.Lock()
        if _, ok := u.server.OnlineMap[newName]; ok {
            u.server.mapLock.Unlock()
            u.SendMsg("当前用户名已被使用\n")
            return
        }
        delete(u.server.OnlineMap, u.Name)
        u.server.OnlineMap[newName] = u
        u.Name = newName
        u.server.mapLock.Unlock()
        u.SendMsg("用户名修改成功: " + u.Name + "\n")
        return
    }

    if strings.HasPrefix(msg, "to|") {
        parts := strings.SplitN(msg, "|", 3)
        if len(parts) != 3 || parts[1] == "" || parts[2] == "" {
            u.SendMsg("格式错误，请使用 to|用户名|消息内容\n")
            return
        }

        remoteName := parts[1]
        content := parts[2]
        u.server.mapLock.RLock()
        remoteUser, ok := u.server.OnlineMap[remoteName]
        u.server.mapLock.RUnlock()
        if !ok {
            u.SendMsg("用户不存在或不在线\n")
            return
        }
        remoteUser.SendMsg("[私聊]" + u.Name + ": " + content + "\n")
        return
    }

    u.server.BroadCast(u, msg)
}
```

---

## 版本九：客户端实现

### 改动目标

实现命令行客户端，支持：

- 公聊
- 私聊
- 改名
- 查询在线用户

### 关键代码

```go
// client/client.go（核心结构）
type Client struct {
    ServerIp   string
    ServerPort int
    Name       string
    conn       net.Conn
    flag       int
}

func (c *Client) SelectUsers() {
    _, _ = c.conn.Write([]byte("who\n"))
}

func (c *Client) UpdateName() {
    fmt.Println(">> 请输入新用户名:")
    fmt.Scanln(&c.Name)
    _, _ = c.conn.Write([]byte("rename|" + c.Name + "\n"))
}

func (c *Client) PrivateChat() {
    var remoteName string
    var chatMsg string

    c.SelectUsers()
    fmt.Println(">> 请输入聊天对象（exit 退出）:")
    fmt.Scanln(&remoteName)
    for remoteName != "exit" {
        fmt.Println(">> 请输入消息（exit 结束当前会话）:")
        fmt.Scanln(&chatMsg)
        for chatMsg != "exit" {
            if chatMsg != "" {
                sendMsg := "to|" + remoteName + "|" + chatMsg + "\n"
                _, _ = c.conn.Write([]byte(sendMsg))
            }
            fmt.Scanln(&chatMsg)
        }
        c.SelectUsers()
        fmt.Println(">> 请输入聊天对象（exit 退出）:")
        fmt.Scanln(&remoteName)
    }
}
```

---

## 项目目录结构

```text
golang-im-system/
├── go.mod
├── server/
│   ├── main.go
│   ├── server.go
│   └── user.go
└── client/
    └── client.go
```

---

## 完整代码

### `go.mod`

```go
module golang-im-system

go 1.20
```

### `server/main.go`

```go
package main

func main() {
    server := NewServer("127.0.0.1", 8888)
    server.Start()
}
```

### `server/server.go`

```go
package main

import (
    "fmt"
    "net"
    "strings"
    "sync"
    "time"
)

type Server struct {
    Ip        string
    Port      int
    OnlineMap map[string]*User
    mapLock   sync.RWMutex
    Message   chan string
}

func NewServer(ip string, port int) *Server {
    return &Server{
        Ip:        ip,
        Port:      port,
        OnlineMap: make(map[string]*User),
        Message:   make(chan string),
    }
}

func (s *Server) ListenMessage() {
    for {
        msg := <-s.Message
        s.mapLock.RLock()
        for _, user := range s.OnlineMap {
            user.C <- msg
        }
        s.mapLock.RUnlock()
    }
}

func (s *Server) BroadCast(user *User, msg string) {
    sendMsg := fmt.Sprintf("[%s]%s: %s", user.Addr, user.Name, msg)
    s.Message <- sendMsg
}

func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    isLive := make(chan struct{})

    go func() {
        buf := make([]byte, 4096)
        for {
            n, err := conn.Read(buf)
            if n == 0 {
                user.Offline()
                return
            }
            if err != nil {
                fmt.Println("conn.Read err:", err)
                return
            }

            msg := strings.TrimSpace(string(buf[:n]))
            if msg != "" {
                user.DoMessage(msg)
            }
            isLive <- struct{}{}
        }
    }()

    timer := time.NewTimer(300 * time.Second)
    defer timer.Stop()

    for {
        select {
        case <-isLive:
            if !timer.Stop() {
                <-timer.C
            }
            timer.Reset(300 * time.Second)
        case <-timer.C:
            user.SendMsg("你被踢了\n")
            close(user.C)
            _ = conn.Close()
            return
        }
    }
}

func (s *Server) Start() {
    address := fmt.Sprintf("%s:%d", s.Ip, s.Port)
    listener, err := net.Listen("tcp", address)
    if err != nil {
        fmt.Println("net.Listen err:", err)
        return
    }
    defer listener.Close()

    go s.ListenMessage()

    fmt.Println(">>> 服务器启动成功，监听", address, "<<<")
    for {
        conn, err := listener.Accept()
        if err != nil {
            fmt.Println("listener.Accept err:", err)
            continue
        }
        go s.Handler(conn)
    }
}
```

### `server/user.go`

```go
package main

import (
    "net"
    "strings"
)

type User struct {
    Name   string
    Addr   string
    C      chan string
    conn   net.Conn
    server *Server
}

func NewUser(conn net.Conn, server *Server) *User {
    userAddr := conn.RemoteAddr().String()
    user := &User{
        Name:   userAddr,
        Addr:   userAddr,
        C:      make(chan string),
        conn:   conn,
        server: server,
    }
    go user.ListenMessage()
    return user
}

func (u *User) ListenMessage() {
    for msg := range u.C {
        _, _ = u.conn.Write([]byte(msg + "\n"))
    }
}

func (u *User) Online() {
    u.server.mapLock.Lock()
    u.server.OnlineMap[u.Name] = u
    u.server.mapLock.Unlock()
    u.server.BroadCast(u, "已上线")
}

func (u *User) Offline() {
    u.server.mapLock.Lock()
    delete(u.server.OnlineMap, u.Name)
    u.server.mapLock.Unlock()
    u.server.BroadCast(u, "下线")
}

func (u *User) SendMsg(msg string) {
    _, _ = u.conn.Write([]byte(msg))
}

func (u *User) DoMessage(msg string) {
    if msg == "who" {
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            onlineMsg := "[" + user.Addr + "]" + user.Name + ": 在线\n"
            u.SendMsg(onlineMsg)
        }
        u.server.mapLock.RUnlock()
        return
    }

    if strings.HasPrefix(msg, "rename|") {
        parts := strings.SplitN(msg, "|", 2)
        if len(parts) != 2 || parts[1] == "" {
            u.SendMsg("格式错误，请使用 rename|新用户名\n")
            return
        }

        newName := parts[1]
        u.server.mapLock.Lock()
        if _, ok := u.server.OnlineMap[newName]; ok {
            u.server.mapLock.Unlock()
            u.SendMsg("当前用户名已被使用\n")
            return
        }
        delete(u.server.OnlineMap, u.Name)
        u.server.OnlineMap[newName] = u
        u.Name = newName
        u.server.mapLock.Unlock()

        u.SendMsg("用户名修改成功: " + u.Name + "\n")
        return
    }

    if strings.HasPrefix(msg, "to|") {
        parts := strings.SplitN(msg, "|", 3)
        if len(parts) != 3 || parts[1] == "" || parts[2] == "" {
            u.SendMsg("格式错误，请使用 to|用户名|消息内容\n")
            return
        }

        remoteName := parts[1]
        content := parts[2]

        u.server.mapLock.RLock()
        remoteUser, ok := u.server.OnlineMap[remoteName]
        u.server.mapLock.RUnlock()
        if !ok {
            u.SendMsg("用户不存在或不在线\n")
            return
        }

        remoteUser.SendMsg("[私聊]" + u.Name + ": " + content + "\n")
        return
    }

    u.server.BroadCast(u, msg)
}
```

### `client/client.go`

```go
package main

import (
    "flag"
    "fmt"
    "io"
    "net"
    "os"
)

type Client struct {
    ServerIp   string
    ServerPort int
    Name       string
    conn       net.Conn
    flag       int
}

func NewClient(serverIp string, serverPort int) *Client {
    client := &Client{
        ServerIp:   serverIp,
        ServerPort: serverPort,
        flag:       -1,
    }

    conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", serverIp, serverPort))
    if err != nil {
        fmt.Println("net.Dial err:", err)
        return nil
    }
    client.conn = conn
    return client
}

func (c *Client) DealResponse() {
    _, _ = io.Copy(os.Stdout, c.conn)
}

func (c *Client) menu() bool {
    var userChoice int
    fmt.Println("====================")
    fmt.Println("1. 公聊模式")
    fmt.Println("2. 私聊模式")
    fmt.Println("3. 修改用户名")
    fmt.Println("0. 退出")
    fmt.Println("====================")
    fmt.Scanln(&userChoice)

    if userChoice < 0 || userChoice > 3 {
        fmt.Println(">> 输入不合法")
        return false
    }

    c.flag = userChoice
    return true
}

func (c *Client) UpdateName() {
    fmt.Println(">> 请输入新用户名:")
    fmt.Scanln(&c.Name)
    _, _ = c.conn.Write([]byte("rename|" + c.Name + "\n"))
}

func (c *Client) PublicChat() {
    var chatMsg string
    fmt.Println(">> 公聊模式，输入 exit 退出")
    fmt.Scanln(&chatMsg)
    for chatMsg != "exit" {
        if chatMsg != "" {
            _, _ = c.conn.Write([]byte(chatMsg + "\n"))
        }
        fmt.Scanln(&chatMsg)
    }
}

func (c *Client) SelectUsers() {
    _, _ = c.conn.Write([]byte("who\n"))
}

func (c *Client) PrivateChat() {
    var remoteName string
    var chatMsg string

    c.SelectUsers()
    fmt.Println(">> 请输入聊天对象（exit 退出）:")
    fmt.Scanln(&remoteName)
    for remoteName != "exit" {
        fmt.Println(">> 请输入消息（exit 结束当前会话）:")
        fmt.Scanln(&chatMsg)
        for chatMsg != "exit" {
            if chatMsg != "" {
                sendMsg := "to|" + remoteName + "|" + chatMsg + "\n"
                _, _ = c.conn.Write([]byte(sendMsg))
            }
            fmt.Scanln(&chatMsg)
        }
        c.SelectUsers()
        fmt.Println(">> 请输入聊天对象（exit 退出）:")
        fmt.Scanln(&remoteName)
    }
}

func (c *Client) Run() {
    for c.flag != 0 {
        for !c.menu() {
        }

        switch c.flag {
        case 1:
            c.PublicChat()
        case 2:
            c.PrivateChat()
        case 3:
            c.UpdateName()
        }
    }
}

var serverIp string
var serverPort int

func init() {
    flag.StringVar(&serverIp, "ip", "127.0.0.1", "设置服务器 IP")
    flag.IntVar(&serverPort, "port", 8888, "设置服务器端口")
}

func main() {
    flag.Parse()

    client := NewClient(serverIp, serverPort)
    if client == nil {
        fmt.Println(">> 连接服务器失败")
        return
    }

    fmt.Println(">> 连接服务器成功")
    go client.DealResponse()
    client.Run()
}
```
