package com.example.test.support;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.net.ServerSocket;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.function.BooleanSupplier;

/**
 * 测试基建骨架：轮询等待、造数、目录断言。放进项目的测试包，包名与后缀按项目改。
 */
public final class ForwardTestSupport {

    private static final long DEFAULT_WAIT_MILLIS = 8000;

    private ForwardTestSupport() {
    }

    /** 轮询等待条件成立，超时抛 AssertionError 并把说明带上。可选的默认超时给足，别让慢机器假红。 */
    public static void await(String message, BooleanSupplier condition) {
        await(message, condition, DEFAULT_WAIT_MILLIS);
    }

    public static void await(String message, BooleanSupplier condition, long timeoutMillis) {
        long deadline = System.currentTimeMillis() + timeoutMillis;
        while (System.currentTimeMillis() < deadline) {
            if (condition.getAsBoolean()) {
                return;
            }
            try {
                Thread.sleep(20);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new AssertionError("等待被中断：" + message);
            }
        }
        throw new AssertionError("等待超时：" + message);
    }

    /** 造一包报文：头部带类型，包身按位置填字节，便于逐字节比对。 */
    public static byte[] packet(int type, int bodyLength) {
        byte[] bytes = new byte[16 + bodyLength];
        bytes[0] = (byte) type;
        for (int i = 16; i < bytes.length; i++) {
            bytes[i] = (byte) (i - 16);
        }
        return bytes;
    }

    /** 造指定大小的载荷，内容按位置生成，用于大报文用例。 */
    public static byte[] payload(int size) {
        byte[] bytes = new byte[size];
        for (int i = 0; i < size; i++) {
            bytes[i] = (byte) (i * 31);
        }
        return bytes;
    }

    public static byte[] concat(byte[]... parts) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (byte[] part : parts) {
            out.write(part, 0, part.length);
        }
        return out.toByteArray();
    }

    /** 列目录里某种后缀的文件，按文件名排序；目录不存在时返回空列表。 */
    public static List<File> filesEndingWith(File dir, String suffix) {
        File[] files = dir.listFiles((d, name) -> name.endsWith(suffix));
        if (files == null) {
            return new ArrayList<>();
        }
        List<File> list = new ArrayList<>(Arrays.asList(files));
        list.sort(Comparator.comparing(File::getName));
        return list;
    }

    public static List<File> failedFiles(File cacheDir) {
        return filesEndingWith(new File(cacheDir, "failed"), ".pkt");
    }

    public static List<File> succeededFiles(File cacheDir) {
        return filesEndingWith(new File(cacheDir, "succeeded"), ".pkt");
    }

    /** 取一个空闲端口，留给稍后才起的服务用。 */
    public static int freePort() {
        try (ServerSocket socket = new ServerSocket(0)) {
            return socket.getLocalPort();
        } catch (IOException e) {
            throw new IllegalStateException("取空闲端口失败", e);
        }
    }
}
