# mock-testing

拿桩把功能链路跑通的通用套路：对端还没实现、不可达、缺硬件起不来、只想验中间段、要复现线上问题或造依赖数据。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `mock-testing` | 技能 | 六步法：划边界、抄契约、写桩、接管、三层验证、收尾还原 |
| `references/method.md` | 参考 | 契约清单模板、各边界的契约差异、四种接管手段与还原 |
| `references/verify-and-pitfalls.md` | 参考 | 三层验证、故障档、收尾清单、按症状查的踩坑清单 |
| `examples/` | 模板 | HTTP 桩、假上游桩、WebSocket 观察器、起停脚本 |

技能按需触发，不注入会话。边界不限于 HTTP：RPC、消息队列、数据库与缓存、文件与对象存储、串口设备、时钟与随机源都按同一套路处理。

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install mock-testing@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install mock-testing@local-team -s project
```

## 使用

说"模拟一下"、"mock 这个接口"、"做个桩"、"假云端"、"造点测试数据"、"不连真环境跑通"、"模拟失败"、"故障注入"、"复现线上问题"、"模拟超时"时自动触发，也可以显式调用：

- `/mock-testing:mock-testing` —— 走一遍六步法

需要频繁在本地或测试环境复现链路问题的项目才装；纯单元测试够用的项目不必装。

## 模板的适用范围

模板以 Linux 加 Python 3 标准库为前提，不引入第三方依赖。

- `http_stub.py`、`ws_probe.py` 与具体项目无关，改路由与字段即可用。
- `cloud_stub.py` 的骨架通用，但"指令下发"的字段形状取自某个真实项目的契约，换项目要照着被替掉的那份源码改字段名。
- `sim_run.sh` 的就绪探测用 `ss` 解析进程号，非 Linux 环境要换成 `lsof` 或平台对应命令。
- 其余边界类型没有模板，照 `method.md` 的套路写。
