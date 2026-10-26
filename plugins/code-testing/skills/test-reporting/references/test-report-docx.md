# 测试报告（DOCX）

## 1 报告结构

按下面的顺序生成，用户另有模板时以用户模板为准：

1. 封面：报告名、组件坐标与版本、报告日期、测试环境、测试依据、用例总数、通过数、失败数。
2. 结果汇总：按功能模块统计用例数、通过数、失败数。
3. 逐条用例：用例编号与标题、功能模块、功能点、优先级、前提条件、操作步骤、预期输出、测试方法、测试结果、执行截图。
4. 页眉：报告名。页脚：页码。

每条用例从新页开始。图片按页面可用高度缩放，避免被推到下一页后留下大片空白。

## 2 用例与证据映射

以下命令使用占位符；按当前项目替换组件名、JAR 名、探针名与异常消息，不要照抄项目路径。

一条用例至少对应一个可复现命令或测试方法。不要用同一张图糊弄多条无关用例。

| 用例类型 | 证据 |
| --- | --- |
| CLI 参数、退出码 | 真实命令 + stdout + stderr + 退出码 |
| 文件转换、输出目录、覆盖 | 真实 CLI 命令 + `转换成功` + `<证据探针>` 的页数、图片数、水印、文字 |
| 异常输入 | 真实命令 + 异常消息 + 输出文件不存在检查 |
| Java API、流、wpg（Word 2010 组合形状）、license、并发 | `mvn -B -Dtest='Class#method' test` 的真实输出 |
| PDF 版式、字体 | 只有用户明确要页面图时才渲染 PDF；默认仍用终端输出，附页数、图片数、字体、文字校验 |

`<证据探针>` 可用 PDFBox 实现，输出示例：

```text
pages=3 images=3 eval=false text=HEADER-VERIFY FOOTER-VERIFY BASIC-PAGE-1 中文测试内容 第1页
```

## 3 捕获真实输出

### 3.1 非登录 shell 的 PATH

用 `bash -c` 跑命令时，`java`、`mvn` 可能不在 PATH。用绝对路径，或显式设置：

```python
maven_bin = os.path.expanduser("~/.sdkman/candidates/maven/current/bin")
env = os.environ.copy()
env["JAVA_HOME"] = os.path.expanduser("~/.sdkman/candidates/java/current")
env["PATH"] = env["JAVA_HOME"] + "/bin:" + maven_bin + ":" + env.get("PATH", "")
subprocess.run(["bash", "-c", cmd], env=env, cwd=workdir,
               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
```

不要用 `bash -lc` 后假设用户 profile 一定加载成功；profile 里的 SDKMAN 初始化不一定在非交互环境生效。

### 3.2 合并 stderr

命令行结果必须同时捕获标准输出与标准错误：

```python
stderr=subprocess.STDOUT
```

否则“转换失败”在 stderr，截图里只剩空白。

### 3.3 Maven 输出过滤

Maven 日志很长，只保留判定需要的行：

```python
keep = []
for line in output.splitlines():
    if ("Tests run:" in line or "BUILD SUCCESS" in line or "BUILD FAILURE" in line
            or "Running " in line or line.startswith("[ERROR]")):
        keep.append(line.strip())
```

单方法运行：

```bash
mvn -B -Dtest='ComponentTest#方法名' test
```

中文方法名可以直接写在 `-Dtest` 里，用单引号包住。执行后保留 `Tests run` 与 `BUILD` 两行即可。

### 3.4 显示规范化

截图里可以缩短路径，但不能改写结果。常用替换：

```python
JAVA_PATH = "/path/to/java"
MVN_PATH = "/path/to/mvn"
JAR_PATH = "/path/to/component.jar"
LICENSE_PATH = "/path/to/license.xml"
cmd = "java -jar " + JAR_PATH + " in.docx out.pdf"

display = (cmd.replace(JAVA_PATH, "java")
              .replace(MVN_PATH, "mvn")
              .replace(JAR_PATH, "<组件>.jar")
              .replace(LICENSE_PATH, "license.xml")
              .replace("/tmp/report/run/", "")
              .replace("/tmp/verify/", "sample/"))
display = re.sub(r"java -cp [^\s]+ (<证据探针>|<字体探针>)", r"\1", display)
```

显示缩短后，报告正文仍保留完整命令与完整路径，保证可复现；截图里用 `…/component.jar` 这类带省略号的写法，避免把缩短值当成真实路径。

输出同样可以去掉工作目录前缀，但异常消息、退出码、页数、图片数、水印状态必须保持原值。

## 4 终端截图

用户要“终端输出结果”时，截图就是一个黑框，内容只有命令与输出。

必须去掉：

- 用例标题栏、模块名、功能点名、测试方法名。
- 顶部红黄绿窗口圆点。
- 底部“测试结果：通过”、退出码条。
- 图片下方的“图 N：执行截图”说明，除非用户要求图注。

保留：

- 命令，首行以 `$` 开头。
- 输出，原样换行。
- 错误行用红色，命令用绿色，普通输出用浅灰色。

AWT 骨架：

```java
int width = 1200;
int lineHeight = 29;
int padding = 30;
int height = padding * 2 + (commandLines.size() + outputLines.size()) * lineHeight;
BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
Graphics2D g = image.createGraphics();
g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
        RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
g.setColor(Color.BLACK);
g.fillRect(0, 0, width, height);
g.setFont(new Font("Noto Sans Mono CJK SC", Font.PLAIN, 20));
```

字体：

- 中文：`Noto Sans CJK SC` 或 `WenQuanYi Micro Hei`。
- 等宽：`Noto Sans Mono CJK SC`。
- 字体缺失时中文会变方块。先装字体再截图，或明确告知用户环境缺字体。

换行按 `FontMetrics.stringWidth` 计算，不要按字符数硬切。

## 5 生成 DOCX

用 Aspose.Words 或用户已有模板。关键设置：

```java
new License().setLicense(licensePath);
Document doc = new Document();
DocumentBuilder builder = new DocumentBuilder(doc);
doc.getFirstSection().getPageSetup().setPaperSize(PaperSize.A4);
doc.getFirstSection().getPageSetup().setTopMargin(56);
doc.getFirstSection().getPageSetup().setBottomMargin(56);
doc.getFirstSection().getPageSetup().setLeftMargin(56);
doc.getFirstSection().getPageSetup().setRightMargin(56);
builder.getFont().setName("宋体");
builder.getFont().setSize(10.5);
```

插图：

```java
BufferedImage img = ImageIO.read(imageFile);
double maxWidth = 16.5 * 28.35;
double maxHeight = 13.5 * 28.35;
double scale = Math.min(maxWidth / img.getWidth(), maxHeight / img.getHeight());
builder.getParagraphFormat().setAlignment(ParagraphAlignment.CENTER);
builder.insertImage(imageFile.getAbsolutePath(),
        img.getWidth() * scale, img.getHeight() * scale);
builder.insertParagraph();
builder.insertBreak(BreakType.PAGE_BREAK);
```

要点：

- 图片最大高度 13 至 14 厘米；超过会把图片推到下一页。
- `insertImage` 后必须插入空段落，否则后续文字会接在图片同一行，出现右侧被截断的图注。
- 用户要“只有一个黑框”时，不要再写图注或“执行截图：”标签。
- 页眉页脚用 `moveToHeaderFooter`，页码用 `insertField("PAGE", "")`。
- 设置 license，避免生成 DOCX 时带评估水印。

## 6 生成后校验

1. ZIP 完整性：`unzip -t report.docx`。
2. 图片数：统计 `word/media/*`，与截图清单一致；允许某条用例 0 张或多张，不要一律按用例数硬卡。
3. 绘图对象数：统计 `word/document.xml` 中的 `<w:drawing>`，与截图清单一致，不按用例数硬卡。
4. 用例编号：把 `word/document.xml` 里同一段落的所有 `<w:t>` 按顺序拼接后再提取 `用例 (\d+)：`；Word 可能把文字拆成多个 run。更稳妥的做法是直接用源用例清单校验。
5. 关键字段：每条用例页有前提条件、操作步骤、预期输出、测试结果。
6. 视觉抽查：用 Aspose 把 DOCX 转 PDF，再用 PDFBox 渲染封面、汇总页、第一条、最后一条页面，至少看四页。

视觉抽查时，Linux 可能没有宋体。可在转换预览时加替换：

```java
FontSettings.getDefaultInstance().addFontSubstitutes(
        "宋体", "Noto Serif CJK SC", "Noto Sans CJK SC");
```

DOCX 本身仍存宋体；Windows 或 WPS 打开时会用宋体显示。

## 7 常见坑

- 截图标题栏、底部通过条：用户明确要“黑框”时全部删掉。
- 截图用 PDF 页面渲染，满屏渐变图片：用户要终端结果时改成实际命令输出。
- 命令里绝对路径太长，截图正文只剩路径：显示时缩短路径，保留输出。
- Maven 方法过滤失败：确认方法名、类名、`#` 与中文编码；先单跑一条验证。
- `Tests run` 是 0：surefire 版本或过滤条件不对，换类级运行验证。
- DOCX 图片被推到下一页：降低最大高度，或把用例文字压短。
- 图片下方文字从右侧开始：`insertImage` 后没有插入空段落。
- 截图文件缺失或损坏：`ImageIO.read` 返回 null，插图前先判空并中止，不要只报空指针。
- 评估水印误判：报告文本含 `Aspose.Words` 不代表有水印，检查 `Evaluation Only` 与页面。
- 报告页数与用例数不一致：每条用例是否漏了分页，或多插了空页。
- 未执行用例删行后报告仍用旧编号：先重排用例表，再重新生成报告与截图。

## 8 交付前问题清单

- 用例表编号连续吗，总数与行数一致吗。
- 每条用例都有实际命令或测试方法吗。
- 截图里是否残留标题栏、通过条、图注。
- 截图里的中文是否正常显示。
- 报告里的用例数、通过数、失败数是否与用例表一致。
- DOCX 的图片数、drawing 数是否等于用例数。
- 是否明确告知用户哪些结果来自实际执行，哪些未执行。
