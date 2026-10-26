# 测试用例表（xlsx）

## 1 何时用

用户给出一份测试用例模板，或要求把测试结果整理成 Excel 用例表时，按本文件执行。先在 `~/docs/<项目>/<日期>/` 下建文件，不放进源码目录。

## 2 先读模板，再建表

读取 xlsx 用 Python 标准库即可，不要假设环境有 openpyxl：

```python
import zipfile, xml.etree.ElementTree as ET

M = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
z = zipfile.ZipFile(path)
shared = []
if 'xl/sharedStrings.xml' in z.namelist():
    root = ET.fromstring(z.read('xl/sharedStrings.xml'))
    shared = [''.join(t.text or '' for t in si.iter(M + 't'))
              for si in root.findall(M + 'si')]
root = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
for row in root.findall('.//' + M + 'sheetData/' + M + 'row'):
    for cell in row.findall(M + 'c'):
        value = cell.find(M + 'v')
        if cell.get('t') == 's' and value is not None:
            print(cell.get('r'), shared[int(value.text)])
```

重点抄这些：

- 表头列名与顺序。
- 信息区占几行、合并范围。
- 每列宽度、行高、是否自动换行。
- 用例编号从几开始，模块与功能点是否纵向合并。
- 用例总数写在哪个单元格。

不要改模板语义。用户只要求填内容时，保持原列名、原顺序、原合并方式。

## 3 标准列结构

本插件使用的测试用例表列结构：

| 列 | 内容 |
| --- | --- |
| A | 功能模块 |
| B | 功能点 |
| C | 编号 |
| D | 用例描述 |
| E | 前提条件 |
| F | 操作步骤(过程描述) |
| G | 预期输出 |
| H | 优先级 |
| I | 测试结果 |
| J | BUG描述 |
| K | 日期 |
| L | 用例编写人 |
| M | 测试人员 |

信息区：

- 第 1 行：系统名称、用例制作时间。
- 第 2 行：模块名称、更新时间。
- 第 3 行：用例描述、确认时间。
- 第 4 行：测试环境、用例总数（条）。
- 第 5 行：空行。
- 第 6 行：表头。
- 第 7 行起：用例。

A 列按功能模块纵向合并，B 列按功能点纵向合并。合并范围只覆盖实际用例行，不覆盖空行。

## 4 结果口径

先用一句话向用户确认口径，再回填。常见口径：

| 口径 | 写法 |
| --- | --- |
| 实际执行且符合预期 | `通过` |
| 实际执行但结果不符 | `未通过`，并在 BUG描述写现象、复现命令、实际输出 |
| 没有执行 | 按用户要求删除整行，或写 `未执行` |
| 用户说“没 BUG 就算通过” | 已执行且未发现缺陷的写 `通过`，不留在“部分通过” |
| 用户说“未执行的就移除” | 删除整行，重编号，重算总数 |

禁止把未执行写成通过。禁止把“部分通过”长期留在表里；用户要求简化时，补测后按实际结果回填，仍未通过就写未通过，不得删行掩盖。

删除行后必须同步：

1. 编号重排为 1 到 N，连续无空号。
2. 用例总数改成 N。
3. 模块统计重算。
4. 合并单元格范围按新的行号重算。
5. 报告与截图目录同步，避免旧编号残留。

## 5 无 openpyxl 时直接写 xlsx

优先用 `scripts/write_test_case_xlsx.py`。它从 TSV 读入 13 列，生成样式、合并、用例总数与冻结窗格，只依赖 Python 标准库：

```bash
python3 write_test_case_xlsx.py cases.tsv out.xlsx \
  --system "系统名称" --module-name "模块名称" --description "功能测试" \
  --environment "JDK8、Linux" --date 2026-10-26
```

TSV 列顺序为：功能模块、功能点、编号、用例描述、优先级、前提条件、操作步骤、预期输出、测试结果、BUG描述、日期、用例编写人、测试人员。字段内的换行写成 `\n`，制表符写成 `\t`。

需要定制样式时再按下面的部件说明手写。xlsx 是一个 ZIP 包，最少需要六个部件：

```text
[Content_Types].xml
_rels/.rels
xl/workbook.xml
xl/_rels/workbook.xml.rels
xl/styles.xml
xl/worksheets/sheet1.xml
```

### 5.1 单元格

用 inlineStr，不依赖 sharedStrings：

```python
from html import escape

def cell(ref, style, text):
    if text is None or text == '':
        return '<c r="%s" s="%d"/>' % (ref, style)
    value = escape(str(text), quote=False).replace('\n', '&#10;')
    return ('<c r="%s" s="%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>'
            % (ref, style, value))
```

注意：

- `&`、`<`、`>` 必须转义。
- 换行写成 `&#10;`，并保留 `xml:space="preserve"`。
- 纯数字编号想显示为文本时也用 inlineStr，避免 Excel 自动转数值。
- 空单元格也要写，否则边框与合并样式可能缺。

### 5.2 样式

`xl/styles.xml` 最少准备这些 cellXfs：

| 索引 | 用途 |
| --- | --- |
| 0 | 默认 |
| 1 | 标题：白字、深蓝底、居中 |
| 2 | 信息区标签：加粗、浅蓝底、居中 |
| 3 | 信息区值：水平左对齐、垂直居中 |
| 4 | 表头：白字、蓝底、居中、换行 |
| 5 | 正文左对齐、顶端对齐、换行 |
| 6 | 正文居中、顶端对齐、换行 |

每列宽度按内容设：

```python
widths = [14, 18, 8, 30, 30, 45, 45, 8, 28, 22, 10, 12, 14]
```

行高按换行数估：

```python
def row_height(values):
    lines = 1
    for text, width in values:
        if not text:
            continue
        count = 0
        for line in str(text).split('\n'):
            units = sum(2 if ord(ch) > 127 else 1 for ch in line)
            count += max(1, (units + width - 1) // width)
        lines = max(lines, count)
    return min(160, max(24, lines * 15 + 6))
```

### 5.3 合并与冻结

```xml
<dimension ref="A1:M20"/>
<cols>
  <col min="1" max="1" width="14" customWidth="1"/>
  <col min="2" max="2" width="18" customWidth="1"/>
</cols>
<mergeCells count="2">
  <mergeCell ref="A1:C4"/>
  <mergeCell ref="A7:A20"/>
</mergeCells>
```

- `dimension` 的结束单元格要覆盖实际最后一行、最后一列。
- `cols` 只写需要的列，`width` 按内容设置。
- `count` 必须等于 `mergeCell` 数量；上面是两条，所以写 2。
- 合并区域只保留左上角值，其余单元格仍写空 `<c>` 并带样式。
- 冻结窗格：

```xml
<sheetViews>
  <sheetView workbookViewId="0">
    <pane ySplit="6" topLeftCell="A7" activePane="bottomLeft" state="frozen"/>
  </sheetView>
</sheetViews>
```

### 5.4 用例总数

用例总数写在信息区单元格里，值取实际用例行数，不写死。删行或增行后重新计算。

## 6 生成后校验

至少做这五项：

```python
import zipfile, xml.etree.ElementTree as ET, re, collections

M = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
z = zipfile.ZipFile(path)
for name in z.namelist():
    if name.endswith(('.xml', '.rels')):
        ET.fromstring(z.read(name))

root = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
rows = root.findall('.//' + M + 'row')
refs = [c.get('r') for r in rows for c in r.findall(M + 'c')]
assert len(refs) == len(set(refs))
```

1. `unzip -t` 无错误。
2. 六个 XML 部件都能解析。
3. 用例编号连续，数量与用例总数一致。
4. 合并单元格数量与范围正确，互不重叠。
5. 状态统计与用例行数一致。

本机没有 Excel/WPS 时，明确写“ZIP 与 XML 校验通过，未做打开后的视觉验证”，不要声称已在 Excel 打开。

## 7 常见坑

- 只写 `sheetData`，漏掉 `dimension`、`cols`、`mergeCells`，Excel 可能能开但排版乱。
- 合并单元格的 `count` 用错，WPS 提示文件损坏。
- 文本里的换行没有写成 `&#10;`，所有步骤挤成一行。
- 编号用数值单元格，删除行后 Excel 自动排序，与内文不一致。
- 删除用例后忘记重编号、重算总数、重算合并范围。
- 用 sharedStrings 时索引错位，单元格显示错误文字；用 inlineStr 时漏掉 `xml:space="preserve"`。
- 读模板时只处理 sharedStrings 与 `sheet1.xml`，遇到 inlineStr 或多工作表会读不到内容；先查 workbook 关系与 `t` 属性。
- 复杂样式超出需要，反而让文件难维护；用例表以可读为先。
