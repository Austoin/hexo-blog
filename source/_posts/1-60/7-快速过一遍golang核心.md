---
title: 从面向对象到多态与异常处理：快速过一遍 Golang 核心知识点
date: 2026-02-26 18:00:00
updated: 2026-02-26 18:00:00
tags: [golang, 教程]
categories: [后端开发]
description: 本文通过对 Golang 核心知识点的快速回顾，结合面向对象、接口、多态、类型断言以及异常处理等内容快速掌握 Go 语言的精髓。文中还提供了完整的代码示例，便于实践和理解。
cover: /img/cover/cover7.webp
top_img: /img/cover/cover7.webp
---

### 一、 核心知识点补充与原理解析

#### 1. Go 与传统面向对象语言的差异
*   **Go 没有什么**：没有 `class`（用 `struct` 代替），没有传统的继承（用组合/嵌套代替），没有方法重载（同名方法编译不通过），没有传统的 `try/catch`（用 `defer/recover` 或多返回值 `error` 处理）。
*   **Go 有什么**：结构体（`struct`）、常量枚举（`iota`）、极简接口实现（Duck Typing 鸭子类型）、并发基因（`goroutine` 与 `channel`）。

#### 2. 面向对象：方法与指针接收者 (Method Sets)
在 Go 中，结构体的方法可以绑定到“值”上，也可以绑定到“指针”上。**方法集（Method Set）规则**：
1. **类型 `T`** 的方法集只包含接收者为 `T` 的方法。
2. **类型 `*T`**（指针）的方法集包含接收者为 `T` 和 `*T` 的所有方法。
3. **调用时的语法糖**：无论定义的是 `T` 还是 `*T`，由于 Go 编译器的语法糖，可以用实例值或指针去调用所有方法（编译器会自动解引用或取地址，如 `u.Run()` 会被转成 `(&u).Run()`）。
4. **接口实现的严格限制**：如果方法的接收者是 `*T`，那么只有 `*T` 类型的指针才算实现了该接口，`T` 类型的值不算实现！

#### 3. 接口与多态 (Duck Typing)
*   **隐式实现**：Go 没有 `implements` 关键字。只要一个结构体实现了某个接口定义的所有方法，它就自动实现了该接口。
*   **多态表现**：定义一个接收接口类型作为参数的函数（如 `PersonCase(person Person)`），传入不同的实体（`Teacher`、`Student`），会执行各自绑定的方法。

#### 4. 类型断言 (Type Assertion)
Go 1.18+已支持真泛型，但在之前版本或处理未知类型时，依然大量使用 `interface{}` 和断言。
*   **语法**：`value, ok := interfaceVar.(TargetType)`。如果转换成功，`ok` 为 `true`，`value` 为目标类型的值；否则 `ok` 为 `false`，安全防止 panic。

#### 5. Defer、Panic 与 Recover (异常处理与执行顺序)
*   **`defer` 的作用**：延迟执行，通常用于资源释放（关闭文件、断开连接）和异常捕获。无论函数是正常 `return` 还是发生 `panic`，`defer` 都会执行。
*   **执行顺序（LIFO）**：后进先出（栈结构），最后声明的 `defer` 最先执行。
*   **参数预计算 vs 闭包**：
    *   如果在 `defer func(j int)(i)` 中通过**传参**传入，参数的值在 `defer` 声明时就已经固定（副本）。
    *   如果在 `defer func() { fmt.Println(i) }()` 中使用**闭包**直接引用外部变量，则会读取变量在函数执行完毕时的**最新值**。
*   **对返回值的修改**：如果函数的返回值是**命名返回值**（如 `func f() (res int)`），`defer` 可以在 `return` 之后、实际返回给调用方之前，修改 `res` 的值。

---

### 二、 完整代码复现

```go
package main

import (
	"fmt"
)

// 1. 枚举与基础结构体定义

// 定义 Gender 枚举
type Gender uint8

const (
	FEMALE  Gender = iota // 0
	MALE                  // 1
	THIRD                 // 2
	UNKNOWN               // 3
)

// 2. 接口与多态的结构体定义

// Person 接口：只要实现了 Run 和 Sleep 方法，就是 Person
type Person interface {
	Run()
	Sleep()
}

// 定义 User 结构体
type User struct {
	Name   string
	Age    uint8
	Gender Gender
}

func (u *User) Run() {
	fmt.Println("user run")
}
func (u *User) Sleep() {
	fmt.Println("user sleep")
}

// 定义 Teacher 结构体
type Teacher struct {
	Name   string
	Age    uint8
	Gender Gender
}

func (t *Teacher) Run() {
	fmt.Println("在公园跑步")
}
func (t *Teacher) Sleep() {
	fmt.Println("在家睡觉")
}

// 定义 Student 结构体
type Student struct {
	// 字段省略
}

func (s *Student) Run() {
	fmt.Println("学生在操场跑步")
}
func (s *Student) Sleep() {
	fmt.Println("学生在宿舍睡觉")
}

// 3. 业务函数：多态与类型断言

// UserCase 测试基础方法调用
func UserCase() {
	fmt.Println("--- UserCase ---")
	u := &User{} // 返回指针
	u.Run()
	u.Sleep()
}

// PersonCase 测试多态与 defer 的场景
func PersonCase(person Person) {
	// defer 演示：无论方法如何，最后都会执行（在 return 之后）
	defer func() {
		fmt.Println("person defer")
	}()

	person.Run()
	person.Sleep()
	return
}

// PersonCase1 测试基于空接口 interface{} 的类型断言
func PersonCase1(person interface{}) {
	fmt.Println("--- PersonCase1 (Type Assertion) ---")
	// 断言：判断传入的参数是否实现了 Person 接口
	if p1, ok := person.(Person); ok {
		p1.Run()
	} else {
		fmt.Println("类型不能识别")
	}
}

// 4. 异常处理：Panic 与 Recover

func TryCatchCase() {
	fmt.Println("--- TryCatchCase ---")
	defer func() {
		err := recover() // 捕获异常
		if err != nil {
			fmt.Println("Recovered:", err)
		}
	}()
	PanicCase()
}

func PanicCase() {
	panic("程序出现异常了") // 触发异常
}

// 5. Defer 的进阶场景：传参 vs 闭包

func DeferCase() {
	fmt.Println("--- DeferCase (传参 vs 闭包) ---")
	i := 1

	// 传参：在声明时计算出参数值 i+1 = 2，放入 defer 栈中
	defer func(j int) {
		fmt.Println("defer j: ", j)
	}(i + 1)

	// 闭包：直接引用外部变量 i。执行时读取 i 的最终真实值
	defer func() {
		i++
		fmt.Println("defer i: ", i)
	}()

	i = 99
	return
	// j = 2, i = 100
}

// 6. Defer 的进阶场景：对返回值与外部变量的影响

var j int = 1

func DeferCase1() {
	fmt.Println("--- DeferCase1 (修改返回值) ---")
	i, i1 := f1()
	// 输出 f1返回的副本(i)、f1返回的指针指向的值(*i1)、外部变量(j)
	fmt.Println(i, *i1, j) 
	// i = 1, i1 = 100, j = 100
}

func f1() (int, *int) {
	defer func() {
		j = 100 // defer 会在 return 之后执行，修改了全局变量 j 的值
	}()
	fmt.Println("f1 j: ", j)
	// 第一个返回值是值拷贝（复制了 1），第二个返回值是指针（指向 j 的内存地址）
	return j, &j
}

// 主函数入口
func main() {
	// 1. 测试对象方法
	UserCase()

	// 2. 测试多态 (Teacher 和 Student 都实现了 Person 接口)
	fmt.Println("--- Polymorphism (多态) ---")
	t := &Teacher{}
	s := &Student{}
	PersonCase(t)
	PersonCase(s)

	// 3. 测试类型断言
	PersonCase1(t)             // 正常识别
	PersonCase1("hello world") // 无法识别

	// 4. 测试异常拦截
	TryCatchCase()

	// 5. 测试 Defer 顺序与闭包
	DeferCase()

	// 6. 测试 Defer 修改变量及指针现象
	DeferCase1()
}
```

### 三、 运行结果与深度剖析

#### 解析 1：DeferCase 的输出
```text
--- DeferCase (传参 vs 闭包) ---
defer i:  100
defer j:  2
```
*   **为什么 `j` 是 2？** `defer func(j int)(i+1)` 中，参数是**值传递**的。当代码执行到这一行时，`i` 还是 1，`i+1` 算出来是 2，所以 `2` 作为参数被打包进了 `defer` 栈。后来 `i` 怎么变，与它无关。
*   **为什么 `i` 是 100？** 闭包里的 `defer func(){ i++ }` 直接拿到了 `i` 的内存地址引用。当函数 `return` 前执行到它时，`i` 已经被赋为了 `99`，闭包再执行 `i++`，所以变成了 `100`。
*   **为什么先打印 `i` 后打印 `j`？** 因为 `defer` 是**后进先出 (LIFO)**，后面的闭包 `defer` 后压入栈，所以先执行。

#### 解析 2：DeferCase1 的输出
```text
--- DeferCase1 (修改返回值) ---
f1 j:  1
1 100 100
```
*   全局变量 `j` 初始是 1。
*   进入 `f1()`，先打印 `f1 j: 1`。
*   执行 `return j, &j`。此时第一部分返回值（匿名）保存了 `j` 的副本，即 `1`；第二部分返回值保存了 `&j`（内存地址）。
*   执行 `defer`，将全局变量 `j` 修改为 `100`。
*   回到 `DeferCase1` 接收：
    *   `i` 拿到了第一部分的值拷贝，依然是 `1`。
    *   `*i1` 是解引用第二部分的指针，由于指向的内存数据已经被 `defer` 改成了 `100`，因此打印 `100`。
    *   外部全局变量 `j` 确实被修改了，打印 `100`。