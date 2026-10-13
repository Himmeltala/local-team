# 测试里起 socket 与线程

## 端口

```java
// 直接用，构造完就知道端口
ServerSocket server = new ServerSocket(0);
int port = server.getLocalPort();
```

```java
// 先占一个号再放开，留给稍后才起的服务
static int freePort() throws IOException {
    try (ServerSocket socket = new ServerSocket(0)) {
        return socket.getLocalPort();
    }
}
```

第二种写法有极小的被抢占风险，能接受的场景：先验证"对端不在时数据留在原地"，再起对端验证"补推"。写死端口不要用，会和开发机上正在跑的服务撞。

## 临时目录

```java
Path cacheDir = Files.createTempDirectory("forward-cache");
```

`/tmp` 下建随机目录，参数只是给人看的前缀。测完不必专门清理，但要保证用例之间不共用同一个目录——上一条用例的残留文件会让断言莫名其妙地多一个。

需要嵌套目录时传 `new File(tmp, "nested/cache")` 给被测代码，顺带验证了目录自动创建。

## 线程收尾

被测代码若起了线程池或后台线程，测试结束前必须停掉：

```java
@AfterEach
void tearDown() {
    if (service != null) {
        service.stop();
        service = null;
    }
}
```

默认的 `Executors.newFixedThreadPool` 与 `new ThreadPoolExecutor(...)` 产出的都是**非 daemon** 线程。不关的话 JVM 不退出，表现是 `mvn test` 跑完用例后长时间挂住，或者 surefire 报 fork 超时。

自己 new 的线程记得 `setDaemon(true)`：

```java
Thread reader = new Thread(runnable, "fake-peer-reader");
reader.setDaemon(true);
reader.start();
```

`synchronized` 之类的锁在停机顺序上也要留意：停止方法里先置标志位、再打断线程、最后关资源，顺序错了会出现"停了但线程还在跑"。

## 接收缓冲被压小的副作用

为了让写方阻塞，常把对端 socket 的接收缓冲压小：

```java
socket.setReceiveBufferSize(1024);
```

副作用很大：小窗口配 TCP 的延迟确认，吞吐会掉几个数量级，几十 MB 的数据传不完，正常路径的用例会被拖到超时。只在需要造"对端不读"的模式里压，正常模式用系统默认缓冲；什么时候压、怎么避免压出半截状态，见 `skills/coverage-testing/references/fake-peer.md`。

一处细节：窗口缩放是在握手时按监听 socket 的缓冲谈定的，在 `accept()` 返回的连接上再改缓冲，效果不如在 `bind` 之前把 `ServerSocket` 的接收缓冲设小来得稳。两种都试过，Linux 上都能压缩窗口，但要让行为可预期，优先设监听端的。

## 断言要等对端那一侧

socket 写返回成功只表示字节进了本机发送缓冲，对端进程可能还没读、甚至已经死了。所以"对端收到了"这件事只能等对端自己的计数：

```java
await("对端应收到完整报文", () -> peer.receivedBytes().length == payload.length);
assertArrayEquals(payload, peer.receivedBytes());
```

被测代码里的"已发送成功"标记（日志、状态字段、归档目录）不能拿来当证据。规则与失败形态见 `skills/coverage-testing/references/stability.md` 的根因一。
