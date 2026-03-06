---
title: golang 实现 Ping 工具：网络协议入门
date: 2026-03-02 9:00:00
updated: 2026-03-02 9:00:00
tags: [golang, 网络]
categories: [后端开发]
description: 这是关于golang实现ping工具的一篇介绍与代码实践的博客文。
cover: /img/cover/cover14.webp
top_img: /img/cover/cover14.webp
---

# 简单写个 Ping 工具：网络协议入门与 Go 语言实战

日常开发和排查网络问题时最常用的命令非 `ping` 莫属。
但 `ping` 命令的底层到底是怎么工作的？下面就介绍的是**用 Go 语言从实现一个简易版的 Ping 工具**！

## 一、 Ping 是什么？有什么用处？

`ping` 是一个计算机网络工具，通常用于测试网络连接的可达性和测量往返时间。在大多数操作系统中，它都是内置的命令行工具。

简单来说，Ping 的工作机制就像日常打招呼：你对着朋友喊一句“喂，听得到吗？”（发送请求），朋友听到后回一句“听到了！”（接收响应）。

Ping 工具主要有以下几个核心用途：
1. **测试主机的可达性**：向目标主机发送一个很小的数据包，如果目标主机正常工作且网络畅通，它将回复一个响应数据包。如果没有响应，说明目标可能离线或网络被阻断（比如被防火墙拦截）。
2. **测量往返时间（RTT）**：Ping 会记录发送请求和收到响应之间的时间差，即往返时间（RTT），通常以毫秒（ms）为单位。这是评估网络延迟的关键指标。
3. **网络故障排除**：如果网络不通，通过 Ping 网关、Ping 外部域名等分步测试，可以快速定位故障节点。
4. **监测网络稳定性**：通过连续发送 Ping 请求，观察是否存在“丢包”现象或延迟剧烈波动，从而判断网络质量。

---

## 二、 Ping 是怎么工作的？

要自己实现一个 Ping 工具，首先必须懂它的底层协议。Ping **并不使用 TCP 或 UDP**，而是基于 **ICMP**。

### 1. ICMP 报文长什么样？
ICMP 报文被封装在 IP 数据包内部传输。一个 ICMP 报文由 **报文头** 和 **数据(Data)** 组成。

这里实现的是“回显请求（Echo Request）”和“回显应答（Echo Reply）”，ICMP 报文头结构如下（共 8 个字节）：

| 字段 (字节大小) | 说明 | Ping 请求中的值 |
| :--- | :--- | :--- |
| **Type (1 byte)** | 报文类型 | `8` (回显请求), `0` (回显应答) |
| **Code (1 byte)** | 报文代码，提供具体的类型信息 | `0` |
| **Checksum (2 bytes)** | 校验和，用于检查报文是否损坏 | 需自行计算 |
| **Identifier (2 bytes)** | 标识符，用于匹配请求和响应 | 通常填入进程或请求次数的 ID |
| **Sequence (2 bytes)** | 序列号，用于标识发送包的顺序 | 从 0 开始递增 |

### 补充 1：网络字节序（大端序）
在计算机中，多字节数据的存储顺序分“大端序（Big-Endian）”和“小端序（Little-Endian）”。**但在网络传输中，国际规定统一使用“大端序”（即网络字节序）**。因此在用代码构建报文时，我们需要将结构体转换为大端序的二进制流。

### 补充 2：IP 报文头部结构
当我们接收到对方主机的回复报文时，操作系统底层交给我们的是一个完整的 IP 数据包。**IP 报文头部固定为 20 个字节**，之后才是我们想要的 ICMP 响应数据。
为了在代码中打印出对方的 IP 和 TTL（生存时间），我们需要知道它们在 IP 头部的准确位置：
*   **第 9 个字节（索引 8）**：TTL（Time To Live），数据包的生存时间。
*   **第 13-16 个字节（索引 12-15）**：Source IP（源 IP 地址），即响应我们请求的对方主机的 IP。

---

## 三、 动手实战：用 Go 语言实现 Ping 工具

### 1. 定义 ICMP 结构与全局变量
先根据前面的理论在本地定义 ICMP 请求报文结构体，并且通过命令获取参数的全局变量：

```go
// 注意：ICMP 结构体字段顺序不能乱，因为底层按字节对齐写入
type ICMP struct {
	Type        uint8  // 类型
	Code        uint8  // 代码
	CheckSum    uint16 // 校验和
	ID          uint16 // ID
	SequenceNum uint16 // 序号
}

var (
	helpFlag bool
	timeout  int64 // 耗时
	size     int   // 数据包大小
	count    int   // 请求次数
	typ      uint8 = 8 // Ping 请求类型设为 8
	code     uint8 = 0 
)

// 绑定命令行参数
func GetCommandArgs() {
	flag.Int64Var(&timeout, "w", 1000, "请求超时时间(ms)")
	flag.IntVar(&size, "l", 32, "发送字节数")
	flag.IntVar(&count, "n", 4, "请求次数")
	flag.BoolVar(&helpFlag, "h", false, "显示帮助信息")
	flag.Parse()
}
```

### 2. 建立网络连接
在发送报文前，我们需要先解析用户输入的 IP/域名，并建立 `icmp` 协议的监听连接：

```go
// 获取目标 IP
desIP := os.Args[len(os.Args)-1]

// 构建 ICMP 连接
// 注意：网络类型必须指定为 "ip:icmp"
conn, err := net.DialTimeout("ip:icmp", desIP, time.Duration(timeout)*time.Millisecond)
if err != nil {
    log.Println(err.Error())
    return
}
defer conn.Close()
```

### 3. 构建报文与计算校验和
这是最核心的一步：我们将结构体转为二进制，填充数据，并计算校验和（Checksum）。

校验和的计算规则是：**将数据按 16 位（2字节）一组两两相加，如果有进位则将高 16 位加到低 16 位上，最后将结果按位取反。**

```go
// 计算校验和的函数
func checkSum(data[]byte) uint16 {
	length := len(data)
	index := 0
	var sum uint32
	// 1. 两个字节拼接且求和
	for length > 1 {
		sum += uint32(data[index])<<8 + uint32(data[index+1])
		length -= 2
		index += 2
	}
	// 2. 处理奇数情况：剩下一个字节直接加上去
	if length == 1 {
		sum += uint32(data[index])
	}

	// 3. 将高 16 位加到低 16 位上，直到高 16 位为 0
	hi := sum >> 16
	for hi != 0 {
		sum = hi + uint32(uint16(sum))
		hi = sum >> 16
	}
	// 4. 返回取反的结果
	return uint16(^sum)
}
```

在发送的 `for` 循环中，我们将这些组装起来：

```go
// 构建请求头
icmp := &ICMP{
    Type:        typ,
    Code:        code,
    CheckSum:    uint16(0), // 初始为 0
    ID:          uint16(i),
    SequenceNum: uint16(i),
}

// 采用大端序将结构体转为二进制
var buffer bytes.Buffer
binary.Write(&buffer, binary.BigEndian, icmp)

// 附加用户指定大小的数据（比如 32 字节的空数据）
data := make([]byte, size)
buffer.Write(data)
data = buffer.Bytes()

// 计算校验和并回填到报文头中
// 校验和位于报文的第 3 和第 4 个字节（索引为 2 和 3）
checkSumRes := checkSum(data)
data[2] = byte(checkSumRes >> 8)
data[3] = byte(checkSumRes)
```

### 4. 发送、接收与解析响应
把数据通过 Socket 扔出去，然后堵塞读取对方回复：

```go
startTime := time.Now()
conn.SetDeadline(time.Now().Add(time.Duration(timeout) * time.Millisecond))

// 发送报文
_, err := conn.Write(data)

// 接收响应包
buf := make([]byte, 1024)
n, err := conn.Read(buf)
if err != nil {
    fmt.Println("请求超时")
    continue
}

// 计算耗时
t := time.Since(startTime).Milliseconds()

// 解析 IP 首部：提取源 IP (buf[12:16]) 和 TTL (buf[8])
// 减去 IP头的20字节和ICMP头的8字节，即为返回的数据大小
fmt.Printf("来自 %d.%d.%d.%d 的回复：字节=%d 时间=%d ms TTL=%d\n", 
    buf[12], buf[13], buf[14], buf[15], n-28, t, buf[8])
```

---

## 四、 运行与测试

### 补充 3：运行权限（必看）
因为程序里用了 `ip:icmp` 来建立**原始套接字（Raw Sockets）**，这种底层网络操作往往会绕过操作系统的部分网络栈。出于安全考虑**绝大部分操作系统都要求程序必须具有管理员/Root 权限才能运行！**

**正确运行方式：**
*   **Mac / Linux系统**：用 `sudo` 运行
    ```bash
    sudo go run main.go -n 4 -l 32 www.baidu.com
    ```
*   **Windows系统**：用“以管理员身份运行”打开 cmd 或 PowerShell 终端，再执行代码。

**运行效果：**
```text
正在 Ping www.baidu.com [110.242.68.3] 具有 32 字节的数据:
来自 110.242.68.3 的回复：字节=32 时间=23 ms TTL=52
来自 110.242.68.3 的回复：字节=32 时间=21 ms TTL=52
来自 110.242.68.3 的回复：字节=32 时间=22 ms TTL=52
来自 110.242.68.3 的回复：字节=32 时间=21 ms TTL=52

110.242.68.3 的 Ping 统计信息:
    数据包: 已发送 = 4，已接收 = 4，丢失 = 0 (0% 丢失)，
往返行程的估计时间(以毫秒为单位):
    最短 = 21，最长 = 23，平均 = 21
```
---

## 五、 小结

这里介绍了一下常用的 `ping` 工具的各项用途，然后是网络协议底层，分析了 ICMP 报文的结构、网络大端序的概念、还有 IPv4 首部的抓取技巧，最后用 Go 语言实现了一个简单的 Ping 命令行工具。

**进阶挑战：**
现在的代码是按顺序发包的（串行），可以在此基础上进行扩展：
1. 用 Go 语言的 `goroutine` 实现高并发的 Ping 扫描（局域网存活主机探测）。
2. 添加对 IPv6 的支持（需要使用 ICMPv6 协议）。

--- 

### 附录：完整可运行代码
<details>
<summary>点击展开查看完整代码</summary>

```go
package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"log"
	"math"
	"net"
	"os"
	"time"
)

var (
	helpFlag bool
	timeout  int64 
	size     int   
	count    int   
	typ      uint8 = 8
	code     uint8 = 0
	SendCnt  int                   
	RecCnt   int                   
	MaxTime  int64 = math.MinInt64 
	MinTime  int64 = math.MaxInt64 
	SumTime  int64                 
)

type ICMP struct {
	Type        uint8  
	Code        uint8  
	CheckSum    uint16 
	ID          uint16 
	SequenceNum uint16 
}

func main() {
	fmt.Println()
	log.SetFlags(log.Llongfile)
	GetCommandArgs()

	if helpFlag {
		displayHelp()
		os.Exit(0)
	}

	desIP := os.Args[len(os.Args)-1]
	conn, err := net.DialTimeout("ip:icmp", desIP, time.Duration(timeout)*time.Millisecond)
	if err != nil {
		log.Println("连接失败, 请检查是否使用管理员/sudo权限运行:", err.Error())
		return
	}
	defer conn.Close()
	
	remoteaddr := conn.RemoteAddr()
	fmt.Printf("正在 Ping %s [%s] 具有 %d 字节的数据:\n", desIP, remoteaddr, size)
	
	for i := 0; i < count; i++ {
		icmp := &ICMP{
			Type:        typ,
			Code:        code,
			CheckSum:    uint16(0),
			ID:          uint16(i),
			SequenceNum: uint16(i),
		}

		var buffer bytes.Buffer
		binary.Write(&buffer, binary.BigEndian, icmp)
		data := make([]byte, size)
		buffer.Write(data)
		data = buffer.Bytes()
		
		checkSum := checkSum(data)
		data[2] = byte(checkSum >> 8)
		data[3] = byte(checkSum)
		
		startTime := time.Now()
		conn.SetDeadline(time.Now().Add(time.Duration(timeout) * time.Millisecond))
		
		_, err := conn.Write(data)
		if err != nil {
			log.Println(err)
			continue
		}
		SendCnt++
		
		buf := make([]byte, 1024)
		n, err := conn.Read(buf)
		if err != nil {
			fmt.Println("请求超时。")
			continue
		}
		RecCnt++
		
		t := time.Since(startTime).Milliseconds()
		fmt.Printf("来自 %d.%d.%d.%d 的回复：字节=%d 时间=%d ms TTL=%d\n", buf[12], buf[13], buf[14], buf[15], n-28, t, buf[8])
		MaxTime = Max(MaxTime, t)
		MinTime = Min(MinTime, t)
		SumTime += t
		time.Sleep(time.Second)
	}

	fmt.Printf("\n%s 的 Ping 统计信息:\n", remoteaddr)
	fmt.Printf("    数据包: 已发送 = %d，已接收 = %d，丢失 = %d (%.f%% 丢失)，\n", SendCnt, RecCnt, count-RecCnt, float64(count-RecCnt)/float64(count)*100)
	if RecCnt > 0 {
		fmt.Println("往返行程的估计时间(以毫秒为单位):")
		fmt.Printf("    最短 = %d ms，最长 = %d ms，平均 = %d ms\n", MinTime, MaxTime, SumTime/int64(RecCnt))
	}
}

func checkSum(data[]byte) uint16 {
	length := len(data)
	index := 0
	var sum uint32
	for length > 1 {
		sum += uint32(data[index])<<8 + uint32(data[index+1])
		length -= 2
		index += 2
	}
	if length == 1 {
		sum += uint32(data[index])
	}
	hi := sum >> 16
	for hi != 0 {
		sum = hi + uint32(uint16(sum))
		hi = sum >> 16
	}
	return uint16(^sum)
}

func GetCommandArgs() {
	flag.Int64Var(&timeout, "w", 1000, "请求超时时间")
	flag.IntVar(&size, "l", 32, "发送字节数")
	flag.IntVar(&count, "n", 4, "请求次数")
	flag.BoolVar(&helpFlag, "h", false, "显示帮助信息")
	flag.Parse()
}

func Max(a, b int64) int64 {
	if a > b { return a }
	return b
}

func Min(a, b int64) int64 {
	if a < b { return a }
	return b
}

func displayHelp() {
	fmt.Println(`选项：
	-n count       要发送的回显请求数。
	-l size        发送缓冲区大小。
	-w timeout     等待每次回复的超时时间(毫秒)。
	-h 	       帮助选项`)
}
```
</details>

*(注：最后的“丢包率”计算公式 `count*2` 逻辑会导致丢失率计算不准，改成 `count - RecCnt` 了，比较符合 Ping 的统计逻辑。)*