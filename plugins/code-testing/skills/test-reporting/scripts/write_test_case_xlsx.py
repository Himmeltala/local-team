#!/usr/bin/env python3
"""Write a test-case workbook from a TSV file using only the Python standard library.

TSV columns, tab separated:
  module, point, id, title, priority, precondition, steps, expected,
  result, bug, date, author, tester  (13 columns)

Escapes inside a field: \\n newline, \\t tab, \\\\ backslash.

Usage:
  python3 write_test_case_xlsx.py cases.tsv out.xlsx \
    --system "组件名" --module-name "公共组件" --description "功能测试" \
    --environment "JDK8、Linux" --date 2026-10-26
"""
import argparse
import os
import zipfile
from html import escape

HEADERS = ["功能模块", "功能点", "编号", "用例描述", "前提条件",
           "操作步骤(过程描述)", "预期输出", "优先级", "测试结果",
           "BUG描述", "日期", "用例编写人", "测试人员"]
WIDTHS = [14, 18, 8, 30, 30, 45, 45, 8, 28, 22, 10, 12, 14]


def unescape(value):
    out = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
        out.append(ch)
        i += 1
    return "".join(out)


def read_cases(path):
    cases = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            fields = [unescape(x) for x in line.rstrip("\n").split("\t")]
            if len(fields) != 13:
                raise ValueError("expected 13 columns, got %d: %s" % (len(fields), line[:80]))
            cases.append(fields)
    return cases


def col_letter(index):
    letters = ""
    while index > 0:
        index, rem = divmod(index - 1, 26)
        letters = chr(65 + rem) + letters
    return letters


def cell(ref, style, value):
    value = "" if value is None else str(value)
    if value == "":
        return '<c r="%s" s="%d"/>' % (ref, style)
    text = escape(value, quote=False).replace("\n", "&#10;")
    return ('<c r="%s" s="%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c>'
            % (ref, style, text))


def row_height(values):
    lines = 1
    for text, width in values:
        if not text:
            continue
        count = 0
        for line in str(text).split("\n"):
            units = sum(2 if ord(ch) > 127 else 1 for ch in line)
            count += max(1, (units + width - 1) // width)
        lines = max(lines, count)
    return min(160, max(24, lines * 15 + 6))


def build_sheet(cases, info):
    rows = []
    merges = ["A1:C4"]

    def add_row(r, cells, height=None):
        body = "".join(cell("%s%d" % (col_letter(i + 1), r), style, text)
                       for i, (style, text) in enumerate(cells))
        attrs = ' r="%d"' % r
        if height:
            attrs += ' ht="%d" customHeight="1"' % height
        rows.append("<row%s>%s</row>" % (attrs, body))

    add_row(1, [(1, info["title"]), (3, ""), (3, ""), (2, "系统名称"),
                (3, info["system"]), (2, "用例制作时间"), (3, info["date"]), (3, "")], 32)
    add_row(2, [(1, ""), (3, ""), (3, ""), (2, "模块名称"),
                (3, info["module_name"]), (2, "更新时间"), (3, info["date"]), (3, "")], 32)
    add_row(3, [(1, ""), (3, ""), (3, ""), (2, "用例描述"),
                (3, info["description"]), (2, "确认时间"), (3, ""), (3, "")], 32)
    add_row(4, [(1, ""), (3, ""), (3, ""), (2, "测试环境"),
                (3, info["environment"]), (2, "用例总数（条）"), (3, str(len(cases))), (3, "")], 34)
    add_row(5, [(3, "")] * 13, 12)
    add_row(6, [(4, h) for h in HEADERS], 34)

    r = 7
    for module, point, cid, title, priority, pre, steps, expected, result, bug, date, author, tester in cases:
        add_row(r, [
            (5, module), (5, point), (6, cid), (5, title), (5, pre),
            (5, steps), (5, expected), (6, priority), (5, result),
            (5, bug), (6, date), (6, author), (6, tester),
        ], row_height([(module, 14), (point, 18), (title, 30), (pre, 30),
                       (steps, 45), (expected, 45), (result, 28), (bug, 22)]))
        r += 1

    last = r - 1
    module_start = 7
    while module_start <= last:
        module_end = module_start
        while module_end < last and cases[module_end - 7][0] == cases[module_start - 7][0]:
            module_end += 1
        if module_end > module_start:
            merges.append("A%d:A%d" % (module_start, module_end))
        point_start = module_start
        while point_start <= module_end:
            point_end = point_start
            while (point_end < module_end
                   and cases[point_end + 1 - 7][0] == cases[point_start - 7][0]
                   and cases[point_end + 1 - 7][1] == cases[point_start - 7][1]):
                point_end += 1
            if point_end > point_start:
                merges.append("B%d:B%d" % (point_start, point_end))
            point_start = point_end + 1
        module_start = module_end + 1

    xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
           '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
           'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
           '<dimension ref="A1:M%d"/>' % last,
           '<sheetViews><sheetView tabSelected="1" workbookViewId="0">'
           '<pane ySplit="6" topLeftCell="A7" activePane="bottomLeft" state="frozen"/>'
           '<selection pane="bottomLeft" activeCell="A7" sqref="A7"/>'
           '</sheetView></sheetViews>',
           '<sheetFormatPr defaultColWidth="9" defaultRowHeight="24" customHeight="1"/>',
           '<cols>']
    for i, width in enumerate(WIDTHS, start=1):
        xml.append('<col min="%d" max="%d" width="%d" customWidth="1"/>' % (i, i, width))
    xml.append('</cols><sheetData>')
    xml.extend(rows)
    xml.append('</sheetData>')
    xml.append('<mergeCells count="%d">' % len(merges))
    for merge in merges:
        xml.append('<mergeCell ref="%s"/>' % merge)
    xml.append('</mergeCells>')
    xml.append('<pageMargins left="0.3" right="0.3" top="0.4" bottom="0.4" '
               'header="0.2" footer="0.2"/>')
    xml.append('</worksheet>')
    return "\n".join(xml)


def styles_xml():
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="0"/>
<fonts count="5">
<font><sz val="10"/><color rgb="FF1F1F1F"/><name val="宋体"/><charset val="134"/></font>
<font><b/><sz val="16"/><color rgb="FFFFFFFF"/><name val="宋体"/><charset val="134"/></font>
<font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="宋体"/><charset val="134"/></font>
<font><b/><sz val="10"/><color rgb="FF1F4E79"/><name val="宋体"/><charset val="134"/></font>
<font><sz val="10"/><color rgb="FF1F1F1F"/><name val="宋体"/><charset val="134"/></font>
</fonts>
<fills count="5">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FF1F4E79"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFDCE6F1"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FF4472C4"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="2">
<border><left/><right/><top/><bottom/><diagonal/></border>
<border><left style="thin"><color rgb="FFBFBFBF"/></left><right style="thin"><color rgb="FFBFBFBF"/></right><top style="thin"><color rgb="FFBFBFBF"/></top><bottom style="thin"><color rgb="FFBFBFBF"/></bottom><diagonal/></border>
</borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="7">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="2" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="left" vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top" wrapText="1"/></xf>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>'''


def write_xlsx(cases, out, info):
    content_types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>'''
    root_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>'''
    workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="功能测试" sheetId="1" r:id="rId1"/></sheets>
</workbook>'''
    workbook_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", content_types)
        z.writestr("_rels/.rels", root_rels)
        z.writestr("xl/workbook.xml", workbook)
        z.writestr("xl/_rels/workbook.xml.rels", workbook_rels)
        z.writestr("xl/styles.xml", styles_xml())
        z.writestr("xl/worksheets/sheet1.xml", build_sheet(cases, info))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--system", default="")
    parser.add_argument("--module-name", default="")
    parser.add_argument("--description", default="功能测试")
    parser.add_argument("--environment", default="")
    parser.add_argument("--date", default="")
    parser.add_argument("--title", default="组件测试用例")
    args = parser.parse_args()
    cases = read_cases(args.input)
    info = {
        "title": args.title, "system": args.system, "module_name": args.module_name,
        "description": args.description, "environment": args.environment, "date": args.date,
    }
    write_xlsx(cases, args.output, info)
    print("written %s, %d cases" % (args.output, len(cases)))


if __name__ == "__main__":
    main()
