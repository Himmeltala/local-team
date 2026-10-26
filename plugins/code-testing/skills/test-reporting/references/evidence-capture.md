# 测试证据捕获

## 1 一条用例一份证据

证据必须能回答三个问题：

1. 跑了什么命令或测试方法。
2. 实际输出了什么。
3. 为什么判定通过或未通过。

没有实际执行的用例，不得生成“通过”截图。没有对应命令的用例，先用 `mvn -B -Dtest='Class#method' test` 找到最小可复现方法，再截图。

## 2 命令与用例的对应

以下命令使用占位符；按当前项目替换组件名、JAR 名与探针名。

优先用真实 CLI 命令。只有 CLI 覆盖不到时才用测试方法。

| 场景 | 命令 |
| --- | --- |
| 正常转换 | `java -jar <组件>.jar in.docx out.pdf` |
| 指定 license | `java -jar <组件>.jar in.docx out.pdf --license license.xml` |
| 关闭完整字体 | `java -jar <组件>.jar in.docx out.pdf --no-full-fonts` |
| 输出目录自动创建 | 输出到不存在的多级目录，再 `ls -l` |
| 异常输入 | 直接跑命令，保留 stderr 与退出码 |
| 输出未残留 | 转换失败后 `test -f out.pdf || echo 输出文件不存在` |
| 同名覆盖 | 先转换 A，再转换 B 到同一路径，再用 `<证据探针>` 看文字 |
| 只读目录 | 非 root 下 `chmod 555 dir`，转换，`chmod 755 dir` 还原；root 下写入仍会成功，不可用此法 |
| Java API 与流 | `mvn -B -Dtest='Class#method' test` |
| 并发 | `mvn -B -Dtest='ConcurrencyTest#method' test` |

## 3 捕获

```python
import os, subprocess

maven_bin = os.path.expanduser("~/.sdkman/candidates/maven/current/bin")
env = os.environ.copy()
env["JAVA_HOME"] = os.path.expanduser("~/.sdkman/candidates/java/current")
env["PATH"] = env["JAVA_HOME"] + "/bin:" + maven_bin + ":" + env.get("PATH", "")

proc = subprocess.run(
    ["bash", "-c", command],
    cwd=workdir,
    env=env,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
output = proc.stdout
exit_code = proc.returncode
```

要点：

- `stderr=subprocess.STDOUT`，否则异常信息丢失。
- 用绝对 `java`、`mvn`，不要依赖登录 shell 的 PATH。
- 每条用例在独立工作目录或独立输出路径运行，避免上一条的残留影响下一条。
- 记录退出码，截图里可以不画底栏，但报告文字里要写清预期退出码。
- 预期异常的命令返回 1 时，报告写“退出码 1（预期），测试结果通过”；不要写成执行失败。

## 4 输出整理

命令行输出保留前 16 行左右。长输出截断时必须插入显式标记，例如 `...（截断 37 行）`，并始终保留错误行、退出码与最后一行。Maven 输出只保留：

```text
[INFO] Running com.example.XxxTest
[INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

显示时缩短路径：

```python
text = (text.replace(java_path, "java")
            .replace(mvn_path, "mvn")
            .replace(jar_path, "<组件>.jar")
            .replace(license_path, "license.xml")
            .replace(workdir + "/", ""))
```

不要改写：

- 异常类型与消息。
- 退出码。
- 页数、图片数、字体名、水印状态。
- `Tests run` 的失败数、错误数。

## 5 判定

| 情况 | 结果 |
| --- | --- |
| 命令退出 0，输出符合预期 | 通过 |
| 预期异常，命令退出非 0，异常类型与消息符合预期，且无残留输出 | 通过 |
| 命令退出 0，但输出不符合预期 | 未通过 |
| 命令退出非 0，但不在预期内 | 未通过 |
| 未执行 | 按用户口径删除或写未执行 |

用户说“没 BUG 就算通过”时，把已执行且无缺陷的写通过；未执行仍不能当通过。用户说“未执行移除”时，删除用例并重编号。

## 6 证据与报告对齐

- 报告里的用例标题、编号、优先级与 xlsx 同源。
- 报告里的结果与 xlsx 的测试结果列一致。
- 截图里的命令与报告里的测试方法一致。
- 删行后重新生成截图与报告，避免旧编号图片残留。
- 报告生成后抽查截图与用例标题是否错位。

## 7 常见坑

- 用 `bash -lc` 跑命令，登录 shell 没有 SDKMAN 的 PATH，截图全是 `command not found`。
- 只捕获 stdout，stderr 的“转换失败”没进截图。
- 实际没跑，凭记忆写输出；用户复现时对不上。
- 把预期异常写成了失败。
- 截图里保留绝对路径，正文全是 `/home/...`，看不到结果；显示可缩短，但报告正文要保留完整命令与完整路径。
- 用 root 跑只读目录用例，`chmod 555` 拦不住写入，误判为通过。
- Maven 输出未过滤，截图里全是下载日志。
- 报告截图与用例错位：截图按旧编号命名，用例表删过行。
