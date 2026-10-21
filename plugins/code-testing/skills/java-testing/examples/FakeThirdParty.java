package com.example.test.support;

import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 进程内假对端骨架：真开监听端口，把收到的字节累积下来供断言。
 * 用到哪个能力留哪个，用不到的删掉。放进项目的测试包，包名按项目改。
 */
public class FakeThirdParty implements Closeable {

    private final ServerSocket serverSocket;
    private final ByteArrayOutputStream received = new ByteArrayOutputStream();
    private final List<Socket> connections = new ArrayList<>();
    private final AtomicInteger acceptedCount = new AtomicInteger();
    private final AtomicBoolean running = new AtomicBoolean(true);
    // false 表示只接受连接不读数据，用来逼出写阻塞
    private volatile boolean reading;
    // 每接受一条连接就回的固定字节，不需要就留空
    private volatile byte[] greeting;

    public FakeThirdParty() throws IOException {
        this(0, true);
    }

    public FakeThirdParty(int port) throws IOException {
        this(port, true);
    }

    public FakeThirdParty(boolean reading) throws IOException {
        this(0, reading);
    }

    public FakeThirdParty(int port, boolean reading) throws IOException {
        this.reading = reading;
        serverSocket = new ServerSocket();
        serverSocket.setReuseAddress(true);
        serverSocket.bind(new InetSocketAddress("127.0.0.1", port));
        Thread acceptThread = new Thread(this::acceptLoop, "fake-peer-accept");
        acceptThread.setDaemon(true);
        acceptThread.start();
    }

    public int port() {
        return serverSocket.getLocalPort();
    }

    /** 一共接受过多少次连接，用来断言客户端确实重连了。 */
    public int acceptedConnections() {
        return acceptedCount.get();
    }

    /** 所有连接累积收到的字节，跨重连也累加。 */
    public byte[] receivedBytes() {
        synchronized (received) {
            return received.toByteArray();
        }
    }

    /** 每接受一条连接就主动回一段数据，用来验证客户端的读线程在干活。 */
    public void replyWith(byte[] data) {
        this.greeting = data;
    }

    /** 踢掉所有当前连接，客户端应当察觉并重连。 */
    public void dropConnections() {
        synchronized (connections) {
            for (Socket socket : connections) {
                closeQuietly(socket);
            }
            connections.clear();
        }
    }

    /** 由「只连不读」切成正常读取：踢掉旧连接，客户端重连后就开始收数据。 */
    public void switchToReading() {
        reading = true;
        dropConnections();
    }

    private void acceptLoop() {
        while (running.get()) {
            Socket socket;
            try {
                socket = serverSocket.accept();
            } catch (IOException e) {
                // 只有监听套接字出问题才退出循环（比如 close()），单条连接的故障不该把监听关掉
                return;
            }
            try {
                acceptedCount.incrementAndGet();
                // 只取一次标志位，避免中途切模式留下半截状态
                boolean readThisConnection = reading;
                if (!readThisConnection) {
                    // 压小接收窗口，让发送方更快撞上写阻塞。
                    // 窗口缩放按监听端谈定，在 bind 前设 ServerSocket 接收缓冲更稳。
                    socket.setReceiveBufferSize(1024);
                }
                synchronized (connections) {
                    connections.add(socket);
                }
                if (readThisConnection) {
                    Thread reader = new Thread(() -> readLoop(socket), "fake-peer-reader");
                    reader.setDaemon(true);
                    reader.start();
                    replyIfNeeded(socket);
                }
            } catch (IOException e) {
                closeQuietly(socket);
            }
        }
    }

    /** 问候数据只该是一小段，它在接受线程上同步写出去，太大或对端不读会卡住接受循环。 */
    private void replyIfNeeded(Socket socket) {
        byte[] data = greeting;
        if (data == null) {
            return;
        }
        try {
            socket.getOutputStream().write(data);
            socket.getOutputStream().flush();
        } catch (IOException ignored) {
        }
    }

    private void readLoop(Socket socket) {
        byte[] buffer = new byte[64 * 1024];
        try (InputStream in = socket.getInputStream()) {
            int read;
            while ((read = in.read(buffer)) > 0) {
                synchronized (received) {
                    received.write(buffer, 0, read);
                }
            }
        } catch (IOException ignored) {
        }
    }

    private static void closeQuietly(Socket socket) {
        try {
            socket.close();
        } catch (IOException ignored) {
        }
    }

    @Override
    public void close() throws IOException {
        running.set(false);
        dropConnections();
        serverSocket.close();
    }
}
