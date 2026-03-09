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

为了让你能边看边验证，全文额外补充了三类信息：

- 设计动机：为什么这一版必须做，不做会出现什么问题。
- 关键细节：并发、锁、通道、协议解析这些最容易踩坑的点。
- 可验证步骤：你可以直接在终端输入什么命令、预期看到什么结果。

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

为什么版本一非常重要：

- 它是后续所有功能的地基，如果监听和连接生命周期不稳定，后续广播、私聊都无法成立。
- 先做“空 Handler”是典型的增量开发思路：先打通主链路，再逐层加能力。
- 这一版的验收标准只有一个：客户端能连上，服务端能稳定接收连接并创建 goroutine。

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
    // 版本一只验证“连接生命周期”是否可控：
    // 1) Accept 能拿到连接；2) Handler 能被调度；3) 连接可被主动关闭。
    // 现在立刻 Close 是刻意的，占位成功后再叠加业务逻辑。
    conn.Close()
}

func (s *Server) Start() {
    // 拼接监听地址，统一由配置的 IP + Port 生成。
    address := fmt.Sprintf("%s:%d", s.Ip, s.Port)
    listener, err := net.Listen("tcp", address)
    if err != nil {
        fmt.Println("net.Listen err:", err)
        return
    }
    defer listener.Close()

    for {
        // Accept 会阻塞，直到有新的客户端连接进来。
        // 这也是服务端常驻运行的核心循环：不断接入，不断分发。
        conn, err := listener.Accept()
        if err != nil {
            fmt.Println("listener.Accept err:", err)
            continue
        }
        // 每个连接一个 goroutine：
        // - 好处：某个客户端慢读/慢写不会拖死其他连接。
        // - 风险：如果不控制连接生命周期，goroutine 会泄漏。
        go s.Handler(conn)
    }
}
```

快速验证（版本一）：

```bash
# 启动服务端
go run ./server

# 新开终端连接（Windows 可用 telnet/nc，或直接用后文 client）
telnet 127.0.0.1 8888
```

预期：服务端无 panic，连接建立后会被立即关闭（因为 Handler 目前是占位实现）。

---

## 版本二：用户上线功能

### 改动目标

引入用户概念，维护在线用户集合，并能广播“某用户上线”。

设计动机：

- 版本一只有连接，没有“用户身份”，所以无法做在线状态和消息路由。
- 把 `conn` 包装成 `User` 后，后续命令（`who`/`rename|`/`to|`）都能围绕用户对象扩展。
- `OnlineMap + RWMutex` 是这个项目并发安全的核心，必须在这个版本定好。

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
    // OnlineMap: 在线用户表，key 是用户名，value 是用户对象。
    OnlineMap map[string]*User
    // mapLock: 保护 OnlineMap，读多写少场景使用 RWMutex。
    mapLock   sync.RWMutex
    // Message: 全局广播通道，所有广播先写入通道，再由监听协程分发。
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
    // 统一广播消息格式，避免客户端端解析多种格式。
    // [地址]用户名: 内容 这种格式便于定位问题（知道是谁、从哪来）。
    sendMsg := fmt.Sprintf("[%s]%s: %s", user.Addr, user.Name, msg)
    // 这里把消息写入总线通道，不直接遍历用户发送。
    // 这样可以把“业务生产消息”和“网络分发消息”解耦。
    s.Message <- sendMsg
}
```

```go
// server/user.go
type User struct {
    Name   string
    Addr   string
    // C: 当前用户自己的消息通道。
    // 服务端广播时把消息塞进这里，再由 ListenMessage 写到 conn。
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
    // 上线要写 OnlineMap（新增 key），必须加写锁。
    // 如果不用锁，多个用户并发上线会触发 map 并发写 panic。
    u.server.mapLock.Lock()
    u.server.OnlineMap[u.Name] = u
    u.server.mapLock.Unlock()

    // 上线后立刻广播，确保其他用户能感知状态变化。
    u.server.BroadCast(u, "已上线")
}
```

---

## 版本三：用户消息广播机制

### 改动目标

让每个用户发言都能被全体在线用户收到。

实现重点：

- 广播采用“生产者-消费者”模型：`BroadCast` 只负责写通道，`ListenMessage` 专门做分发。
- 这样的解耦能减少锁持有时间，避免在业务协程里直接遍历全体用户。
- 后续私聊不会走这条链路，广播和私聊职责会自然分开。

### 关键代码

```go
// server/server.go
func (s *Server) ListenMessage() {
    for {
        // 阻塞读取全局广播消息。
        // 只要没有消息，这个协程就会挂起，不会空转占 CPU。
        msg := <-s.Message

        // 遍历在线用户是读操作，使用读锁允许并发读取。
        s.mapLock.RLock()
        for _, user := range s.OnlineMap {
            // 把广播消息投递到每个用户自己的通道。
            // 后续真正写网络连接由 user.ListenMessage 统一处理。
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
            // n == 0 代表连接正常关闭。
            // 必须执行 Offline，否则 OnlineMap 会留下脏在线数据。
            user.Offline()
            return
        }
        if err != nil {
            fmt.Println("conn.Read err:", err)
            return
        }
        // TrimSpace 去掉换行和首尾空白：
        // - 避免出现仅回车也被广播的噪音消息。
        // - 为后续命令解析（who/rename/to）提供干净输入。
        msg := strings.TrimSpace(string(buf[:n]))
        s.BroadCast(user, msg)
    }
}
```

---

## 版本四：用户业务层封装

### 改动目标

把“解析消息、执行业务”收敛到 `User`，`Server.Handler` 只负责生命周期调度。

这样拆分后的好处：

- `server.go` 关注连接管理（接入、读取、超时、断开）。
- `user.go` 关注业务命令（who / rename / to / 默认广播）。
- 后续加命令时不用改连接层，降低回归风险。

### 关键代码

```go
// server/user.go
func (u *User) Offline() {
    // 下线是删除 OnlineMap 的写操作，必须持有写锁。
    u.server.mapLock.Lock()
    delete(u.server.OnlineMap, u.Name)
    u.server.mapLock.Unlock()
    // 删除映射后再广播下线，避免收到广播的用户立刻查询时出现脏读。
    u.server.BroadCast(u, "下线")
}

func (u *User) SendMsg(msg string) {
    // 对单个连接的底层写入口。
    // 这里忽略错误是为了简化教学，生产环境应记录并断开异常连接。
    _, _ = u.conn.Write([]byte(msg))
}

func (u *User) DoMessage(msg string) {
    // DoMessage 是业务分发入口：
    // 版本四先保留“默认广播”，后续逐步加 who/rename/to 等命令分支。
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

实现要点：

- `who` 是只读命令，读 `OnlineMap` 用读锁，不阻塞其他读请求。
- 返回给发起者本人，不走全局广播，避免污染聊天频道。
- 输出格式保持稳定，客户端可以据此做自动解析（如果后续要升级 UI）。

### 关键代码

```go
// server/user.go
func (u *User) DoMessage(msg string) {
    if msg == "who" {
        // who 是纯读取场景，用 RLock 允许并发读。
        // 与写锁相比，读锁在查询频繁时吞吐更高。
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            // 在线列表只回给当前请求者，不走广播。
            // 否则所有人都会看到谁在执行 who，体验和性能都很差。
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

实现要点：

- 改名是“读 + 写”组合操作，必须放在同一段写锁内完成，避免竞态条件。
- 名称冲突必须先判断再修改 map，否则会覆盖已有在线用户。
- 采用 `rename|新名字` 文本协议，简单可读，便于后续升级成结构化协议。

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
        // SplitN(..., 2) 只切一刀：
        // - 第 1 段是命令 rename
        // - 第 2 段整体作为新用户名
        // 这样即使用户名里出现 '|'，也不会被过度切分。
        parts := strings.SplitN(msg, "|", 2)
        if len(parts) != 2 || parts[1] == "" {
            u.SendMsg("格式错误，请使用 rename|新用户名\n")
            return
        }
        newName := parts[1]

        // 下面是“检查重名 + 更新映射”的临界区，必须一次性持有写锁。
        // 否则可能出现并发改名竞态：两个用户同时通过重名检查。
        u.server.mapLock.Lock()
        if _, ok := u.server.OnlineMap[newName]; ok {
            u.server.mapLock.Unlock()
            u.SendMsg("当前用户名已被使用\n")
            return
        }

        // 先删旧 key，再写新 key，确保 map 中只有一个当前用户映射。
        // 顺序反过来也行，但必须保证两步都在同一把锁内完成。
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

实现要点：

- 连接读取协程负责“上报活跃信号”到 `isLive`。
- 主协程用 `select + timer` 统一处理“活跃重置”与“超时踢出”。
- `timer.Stop` 返回值必须处理，否则可能出现定时器通道残留导致误踢。

### 关键代码

```go
// server/server.go
func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    // isLive: 用户活跃信号通道。
    // 读取协程每收到一条客户端输入，就投递一次活跃事件给主协程。
    isLive := make(chan struct{})

    go func() {
        buf := make([]byte, 4096)
        for {
            n, err := conn.Read(buf)
            if n == 0 {
                // 客户端主动断开，清理在线状态后结束读取协程。
                user.Offline()
                return
            }
            if err != nil {
                fmt.Println("conn.Read err:", err)
                return
            }

            msg := strings.TrimSpace(string(buf[:n]))
            user.DoMessage(msg)
            // 有任何输入都认为连接活跃。
            // 该信号会触发主协程重置踢出计时器。
            isLive <- struct{}{}
        }
    }()

    // 空闲 300 秒自动踢出。
    // 这个时间常量在真实项目里建议做成可配置项。
    timer := time.NewTimer(300 * time.Second)
    defer timer.Stop()

    for {
        select {
        case <-isLive:
            // 先 stop，再按需清空通道，最后 reset，避免 timer 误触发。
            // 如果不清空 timer.C，下一轮 select 可能立刻命中超时分支。
            if !timer.Stop() {
                <-timer.C
            }
            timer.Reset(300 * time.Second)
        case <-timer.C:
            user.SendMsg("你被踢了\n")
            // 关闭用户消息通道，退出该用户写协程。
            // 然后关闭连接，确保读协程也能尽快退出。
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

实现要点：

- 协议格式：`to|用户名|内容`，必须严格校验三段。
- 找目标用户只需要读锁；找到后直接 `remoteUser.SendMsg`，不进入广播通道。
- 私聊失败（用户不存在/离线）要明确回执，避免客户端误判为发送成功。

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
        // to|目标用户名|消息内容
        // SplitN(..., 3) 是为了把第 3 段当成完整正文保留下来。
        parts := strings.SplitN(msg, "|", 3)
        if len(parts) != 3 || parts[1] == "" || parts[2] == "" {
            u.SendMsg("格式错误，请使用 to|用户名|消息内容\n")
            return
        }

        remoteName := parts[1]
        content := parts[2]
        // 查找目标用户是读操作，用读锁即可。
        // 锁粒度尽量小：取到 remoteUser 后立刻释放锁，避免影响其他命令。
        u.server.mapLock.RLock()
        remoteUser, ok := u.server.OnlineMap[remoteName]
        u.server.mapLock.RUnlock()
        if !ok {
            u.SendMsg("用户不存在或不在线\n")
            return
        }
        // 私聊消息仅发送给目标用户，不经过全局广播。
        // 这样不会污染公共频道，也减少无意义的通道分发开销。
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

实现要点：

- 客户端和服务端通过纯文本协议交互，所有命令最终都是 `conn.Write`。
- `DealResponse` 持续把服务端消息打印到终端，保证“收消息”和“发命令”并行。
- 菜单模式本质上是一个状态机：选择模式 -> 执行业务 -> 返回菜单。

### 关键代码

```go
// client/client.go（核心结构）
type Client struct {
    ServerIp   string
    ServerPort int
    Name       string
    conn       net.Conn
    // flag 表示当前菜单模式：
    // 1 公聊、2 私聊、3 改名、0 退出。
    // 这个字段就是客户端状态机的“当前状态”。
    flag       int
}

func (c *Client) SelectUsers() {
    // who 命令：查询在线列表。
    // 单独封装是为了复用：私聊前后都要刷新在线用户。
    _, _ = c.conn.Write([]byte("who\n"))
}

func (c *Client) UpdateName() {
    fmt.Println(">> 请输入新用户名:")
    fmt.Scanln(&c.Name)
    // 协议格式：rename|新名字（发送时会拼接换行）
    // 结尾换行用于和服务端 Read + TrimSpace 的读取逻辑配合。
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
                // 协议格式：to|目标用户|消息内容（发送时会拼接换行）
                // 服务端会按 SplitN(..., 3) 解析。
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

下面是可直接运行的完整版本。我把注释强化为三层：

- 做什么：当前代码块的职责。
- 为什么：为什么选这种写法。
- 风险点：如果忽略这个细节会出什么 bug。

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
    // 在线用户表，key=用户名，value=用户对象。
    // 读写都在多个 goroutine 中发生，必须配合 mapLock 使用。
    OnlineMap map[string]*User
    // 保护 OnlineMap 的并发读写。
    // 读多写少场景下，RWMutex 比 Mutex 并发性更好。
    mapLock   sync.RWMutex
    // 全局广播通道：所有广播消息都先进通道，再统一分发。
    // 这是“业务线程”和“网络分发线程”的边界。
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

        // 广播分发：读 OnlineMap 用读锁。
        // 如果这里不加锁，并发上线/下线时会触发 map 读写冲突。
        s.mapLock.RLock()
        for _, user := range s.OnlineMap {
            // 投递到每个用户自己的消息通道。
            // 若某个用户消费过慢，这里会被背压阻塞（教学版本保持简单）。
            user.C <- msg
        }
        s.mapLock.RUnlock()
    }
}

func (s *Server) BroadCast(user *User, msg string) {
    // 统一消息格式，便于客户端展示和日志排查。
    // 消息先入总线，再由 ListenMessage 扇出给所有在线用户。
    sendMsg := fmt.Sprintf("[%s]%s: %s", user.Addr, user.Name, msg)
    s.Message <- sendMsg
}

func (s *Server) Handler(conn net.Conn) {
    user := NewUser(conn, s)
    user.Online()

    // 活跃信号通道：用户有输入就写入一次。
    // 用 struct{} 零内存开销，语义只关心“事件发生”。
    isLive := make(chan struct{})

    go func() {
        buf := make([]byte, 4096)
        for {
            n, err := conn.Read(buf)
            if n == 0 {
                // 对端关闭连接：及时下线，避免 OnlineMap 残留僵尸用户。
                user.Offline()
                return
            }
            if err != nil {
                fmt.Println("conn.Read err:", err)
                return
            }

            msg := strings.TrimSpace(string(buf[:n]))
            if msg != "" {
                // 真正的业务分发入口：who/rename/to/广播都在 DoMessage。
                user.DoMessage(msg)
            }
            // 重置活跃状态：通知主协程“用户还活着”。
            isLive <- struct{}{}
        }
    }()

    // 300 秒无输入则踢出。
    // 生产环境建议改为配置项，比如从 env 或配置文件读取。
    timer := time.NewTimer(300 * time.Second)
    defer timer.Stop()

    for {
        select {
        case <-isLive:
            // 标准定时器重置写法，避免误触发：
            // 1) Stop 返回 false 说明计时器已触发或将触发；
            // 2) 需要读掉 timer.C 残留值；
            // 3) 再 Reset 到下一轮超时窗口。
            if !timer.Stop() {
                <-timer.C
            }
            timer.Reset(300 * time.Second)
        case <-timer.C:
            user.SendMsg("你被踢了\n")
            // 关闭用户消息通道，结束写协程。
            // 再关闭网络连接，触发读取协程退出，避免 goroutine 泄漏。
            close(user.C)
            _ = conn.Close()
            return
        }
    }
}

func (s *Server) Start() {
    // 统一拼接监听地址，便于后续改配置来源（命令行/env）。
    address := fmt.Sprintf("%s:%d", s.Ip, s.Port)
    listener, err := net.Listen("tcp", address)
    if err != nil {
        fmt.Println("net.Listen err:", err)
        return
    }
    defer listener.Close()

    // 独立广播协程：持续消费 Message 并分发给在线用户。
    go s.ListenMessage()

    fmt.Println(">>> 服务器启动成功，监听", address, "<<<")
    for {
        // 主循环只做两件事：接入连接 + 派发 Handler。
        conn, err := listener.Accept()
        if err != nil {
            fmt.Println("listener.Accept err:", err)
            continue
        }
        // 一连接一协程，隔离各客户端网络波动。
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
    // 用户专属消息通道。
    // 广播/私聊最终都先写入这里，再统一走 ListenMessage 写 conn。
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
        // 统一在这里把通道消息写到网络连接。
        // 集中写出口便于后续做限流、日志、错误处理。
        _, _ = u.conn.Write([]byte(msg + "\n"))
    }
}

func (u *User) Online() {
    // 上线=写 OnlineMap，必须加写锁。
    u.server.mapLock.Lock()
    u.server.OnlineMap[u.Name] = u
    u.server.mapLock.Unlock()
    // 广播顺序放在入表之后，保证其他用户 who 能立即看到。
    u.server.BroadCast(u, "已上线")
}

func (u *User) Offline() {
    // 下线先删映射，再广播，避免出现“已下线但 still online”短暂错乱。
    u.server.mapLock.Lock()
    delete(u.server.OnlineMap, u.Name)
    u.server.mapLock.Unlock()
    u.server.BroadCast(u, "下线")
}

func (u *User) SendMsg(msg string) {
    // 单连接主动写消息。
    // 教学代码忽略写错误；生产代码应处理短写/断连。
    _, _ = u.conn.Write([]byte(msg))
}

func (u *User) DoMessage(msg string) {
    if msg == "who" {
        // who: 查询在线用户。
        // 读多写少场景下使用读锁，减少对改名/上下线写操作的阻塞。
        u.server.mapLock.RLock()
        for _, user := range u.server.OnlineMap {
            onlineMsg := "[" + user.Addr + "]" + user.Name + ": 在线\n"
            u.SendMsg(onlineMsg)
        }
        u.server.mapLock.RUnlock()
        return
    }

    if strings.HasPrefix(msg, "rename|") {
        // rename|新用户名
        // SplitN(..., 2) 只切两段，保证用户名中的其余字符原样保留。
        parts := strings.SplitN(msg, "|", 2)
        if len(parts) != 2 || parts[1] == "" {
            u.SendMsg("格式错误，请使用 rename|新用户名\n")
            return
        }

        newName := parts[1]
        // 临界区：重名检查 + OnlineMap 原子更新必须放在同一把写锁内。
        u.server.mapLock.Lock()
        if _, ok := u.server.OnlineMap[newName]; ok {
            u.server.mapLock.Unlock()
            u.SendMsg("当前用户名已被使用\n")
            return
        }

        // 原子更新用户名映射：删旧 key、写新 key、更新 user.Name。
        delete(u.server.OnlineMap, u.Name)
        u.server.OnlineMap[newName] = u
        u.Name = newName
        u.server.mapLock.Unlock()

        u.SendMsg("用户名修改成功: " + u.Name + "\n")
        return
    }

    if strings.HasPrefix(msg, "to|") {
        // to|目标用户名|消息内容
        // SplitN(..., 3) 让第 3 段保留完整正文（包括可能的分隔符）。
        parts := strings.SplitN(msg, "|", 3)
        if len(parts) != 3 || parts[1] == "" || parts[2] == "" {
            u.SendMsg("格式错误，请使用 to|用户名|消息内容\n")
            return
        }

        remoteName := parts[1]
        content := parts[2]

        // 查目标用户属于读操作，短暂持有读锁即可。
        u.server.mapLock.RLock()
        remoteUser, ok := u.server.OnlineMap[remoteName]
        u.server.mapLock.RUnlock()
        if !ok {
            u.SendMsg("用户不存在或不在线\n")
            return
        }

        // 私聊只发给目标用户，不进入广播通道。
        remoteUser.SendMsg("[私聊]" + u.Name + ": " + content + "\n")
        return
    }

    // 未命中任何命令时，按公聊广播处理。
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
    // 1 公聊，2 私聊，3 改名，0 退出。
    // 等价于一个简单的菜单状态机。
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
    // 持续读取服务端输出并打印。
    // 必须放到独立 goroutine，否则主线程会阻塞在菜单输入上。
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
    // rename 命令协议：rename|新用户名（发送时会拼接换行）
    // 行尾换行用于让服务端按行读取更稳定。
    _, _ = c.conn.Write([]byte("rename|" + c.Name + "\n"))
}

func (c *Client) PublicChat() {
    var chatMsg string
    fmt.Println(">> 公聊模式，输入 exit 退出")
    fmt.Scanln(&chatMsg)
    for chatMsg != "exit" {
        if chatMsg != "" {
            // 公聊就是直接把原始文本发给服务端。
            // 服务端未命中命令分支时会走默认广播。
            _, _ = c.conn.Write([]byte(chatMsg + "\n"))
        }
        fmt.Scanln(&chatMsg)
    }
}

func (c *Client) SelectUsers() {
    // who 命令协议。
    // 私聊前先拉一遍在线列表，减少输错目标用户概率。
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
                // 私聊命令协议：to|目标用户|消息（发送时会拼接换行）
                // 对应服务端 DoMessage 的 to 分支。
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
    // 主循环：不停显示菜单，直到用户选择 0 退出。
    for c.flag != 0 {
        // menu 负责输入校验，不合法就留在当前轮继续输入。
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
