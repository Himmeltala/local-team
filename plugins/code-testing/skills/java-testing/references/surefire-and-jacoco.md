# surefire 与 JaCoCo

## surefire 与 JUnit 5

surefire 2.22 以前不认识 JUnit 5（junit-jupiter），表现是：测试类摆在 `src/test/java` 下、依赖也在，`mvn test` 却一条不跑，还给你 BUILD SUCCESS。判断办法是看输出里的 `Tests run:` 那行——没有这行就说明没跑起来。

Spring Boot 2.2 以上通过 `spring-boot-starter-test` 自带 junit-jupiter，surefire 版本由 spring-boot-starter-parent 统一管理，一般都对得上。父 pom 若不是 spring-boot-starter-parent，得自己确认 surefire 版本。

## 测试日志去哪了

父 pom 里若配了：

```xml
<redirectTestOutputToFile>true</redirectTestOutputToFile>
```

测试期间的日志不会打到控制台，而是写到：

```
target/surefire-reports/<测试类全名>-output.txt
```

排查偶发失败时这份文件最有用：里面是这次运行的时间线，能看出那一刻各线程在干什么。别只盯控制台，会以为日志没打。

## forkCount=0 的坑

有些父 pom 为了让 native 库加载正常，配了：

```xml
<forkCount>0</forkCount>
```

意思是测试**不开子进程**，直接在 Maven 自己的 JVM 里跑。这时 JaCoCo 的标准接法失效：`prepare-agent` goal 生成的 `argLine` 是传给 fork 出来的测试进程的，没有 fork 就没人接。

两条出路：

**一、换掉 forkCount。** 改成 1 让 surefire 开子进程，JaCoCo 按标准流程工作。父 pom 是共享的话别改，会影响别人的项目。

**二、把 agent 挂到 Maven JVM 上。** 不动任何构建配置，命令行给 Maven 加启动参数：

```bash
AGENT=~/.m2/repository/org/jacoco/org.jacoco.agent/0.8.8/org.jacoco.agent-0.8.8-runtime.jar
MAVEN_OPTS="-javaagent:$AGENT=destfile=$PWD/target/jacoco.exec,includes=com.example.*" mvn -B test
mvn -B org.jacoco:jacoco-maven-plugin:0.8.8:report
```

**这条路只在测试确实跑在 Maven JVM 里时有效。** 项目若没配 `forkCount=0`（默认是 1），测试跑在子进程里，agent 挂到 Maven 上只会得到一个空报告——不是报错，是静默地一片空白。先确认测试到底在哪跑：日志里 surefire 输出的 fork 数量，或者直接看项目配的 `forkCount`。

要点：

- `includes=包前缀.*` 限定只统计自己的代码，不然 Maven 自身与第三方库都会被算进分母。
- `org.jacoco:jacoco-maven-plugin:0.8.8:report` 是命令行直接调插件，不需要 pom 里声明，也不改构建。
- 版本要匹配 JVM：0.8.8 支持到 Java 17，Java 21 要 0.8.11 以上。
- 报告落在 `target/site/jacoco/`，`jacoco.csv` 便于脚本解析，`index.html` 便于人看。

## 读报告

`jacoco.csv` 每行一个类，字段是 `*_MISSED` 与 `*_COVERED` 成对出现。看未覆盖的**行号清单**要读 `jacoco.xml`，逐行的数据在 `<sourcefile>` 的 `<line>` 节点上（不在 `<class>` 下）：

```python
for sf in pkg.findall('sourcefile'):
    miss = [int(l.get('nr')) for l in sf.findall('line')
            if int(l.get('ci')) == 0 and int(l.get('mi')) > 0]
```

拿到行号后对着源码看那一行是什么，再决定补不补。
