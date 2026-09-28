# mock-testing

拿桩把功能链路跑通的套路。适用于对端还没实现、对端不可达、对端缺硬件起不来，或者只想验链路中间段的场合。

## 管什么

一条技能 `mock-testing`，按需触发，不注入会话：

- 六步法：划清各端哪些真跑哪些做桩、从源码抄契约、纯标准库写桩、把地址指到桩上、分三层验证、收尾还原。
- 三份参考：契约清单模板、接管手段与还原、验证与收尾清单，外加一份按症状组织的踩坑清单。
- 四份可照抄模板：HTTP 桩、假上游桩、WebSocket 观察器、起停脚本。

## 三条硬规矩

1. 契约从被替换方的源码抄，失败分支与成功分支同等对待。
2. 桩只补缺口，本机能真跑的端不许用桩替。
3. 不碰共享与生产文件，改用只读副本加参数指向。

## 什么时候装

需要频繁在本地或测试环境复现链路问题的项目。纯单元测试够用的项目不必装。

## 目录

```
mock-testing/
├── .claude-plugin/plugin.json
├── README.md
├── docs/maintainer-notes.md
└── skills/mock-testing/
    ├── SKILL.md
    ├── references/     契约、接管、验证收尾、踩坑
    └── examples/       http_stub.py、cloud_stub.py、ws_probe.py、sim_run.sh
```

## 模板的适用范围

模板以 Linux 加 Python 3 标准库为前提，不引入第三方依赖。

- `http_stub.py`、`ws_probe.py` 与具体项目无关，改路由与字段即可用。
- `cloud_stub.py` 的骨架通用，但"指令下发"的字段形状取自某个真实项目的契约，换项目要照着被替掉的那份源码改字段名。
- `sim_run.sh` 的就绪探测用 `ss` 解析进程号，非 Linux 环境要换成 `lsof` 或平台对应命令。
