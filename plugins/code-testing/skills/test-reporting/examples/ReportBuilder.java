import com.aspose.words.BreakType;
import com.aspose.words.Document;
import com.aspose.words.DocumentBuilder;
import com.aspose.words.HeaderFooterType;
import com.aspose.words.License;
import com.aspose.words.PaperSize;
import com.aspose.words.ParagraphAlignment;
import com.aspose.words.SaveFormat;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.File;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 用例报告骨架：封面、汇总、逐条用例、黑框截图。
 *
 * <p>把 cases 换成从 xlsx 或测试结果读取的数据即可。截图文件由 TerminalShot 生成。</p>
 * <p>依赖 Aspose.Words 与有效 license；未配置 license 时文档会带评估水印。</p>
 */
public final class ReportBuilder {

    private ReportBuilder() {
    }

    public static void build(List<Case> cases, File output, String licensePath) throws Exception {
        if (licensePath != null && new File(licensePath).isFile()) {
            new License().setLicense(licensePath);
        }
        Document doc = new Document();
        DocumentBuilder builder = new DocumentBuilder(doc);
        doc.getFirstSection().getPageSetup().setPaperSize(PaperSize.A4);
        doc.getFirstSection().getPageSetup().setTopMargin(56);
        doc.getFirstSection().getPageSetup().setBottomMargin(56);
        doc.getFirstSection().getPageSetup().setLeftMargin(56);
        doc.getFirstSection().getPageSetup().setRightMargin(56);
        builder.getFont().setName("宋体");
        builder.getFont().setNameFarEast("宋体");
        builder.getFont().setSize(10.5);
        builder.getParagraphFormat().setLineSpacing(16);

        cover(builder, cases);
        summary(builder, cases);

        for (Case item : cases) {
            casePage(builder, item);
        }

        headerFooter(builder);
        doc.updateFields();
        doc.save(output.getAbsolutePath(), SaveFormat.DOCX);
    }

    private static void cover(DocumentBuilder builder, List<Case> cases) throws Exception {
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.CENTER);
        builder.getFont().setSize(26);
        builder.getFont().setBold(true);
        builder.writeln("组件测试报告");
        builder.getFont().setSize(14);
        builder.getFont().setBold(false);
        builder.writeln("com.example:component 1.0.0");
        builder.writeln();
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.LEFT);
        builder.getFont().setSize(11);
        builder.writeln("报告日期：" + LocalDate.now());
        builder.writeln("测试环境：JDK、操作系统、依赖版本");
        builder.writeln("测试依据：需求文档、测试用例表");
        builder.writeln("用例总数：" + cases.size() + " 条");
        builder.writeln("通过：" + count(cases, "通过") + " 条");
        builder.writeln("失败：" + count(cases, "未通过") + " 条");
        builder.writeln();
        builder.writeln("说明：每条用例包含标题、前提条件、操作步骤、预期输出、测试结果与执行截图。");
        builder.insertBreak(BreakType.PAGE_BREAK);
    }

    private static void summary(DocumentBuilder builder, List<Case> cases) throws Exception {
        builder.getFont().setSize(16);
        builder.getFont().setBold(true);
        builder.writeln("测试结果汇总");
        builder.getFont().setSize(10.5);
        builder.getFont().setBold(false);
        builder.writeln("用例总数 " + cases.size() + " 条，通过 " + count(cases, "通过")
                + " 条，未通过 " + count(cases, "未通过") + " 条。");
        builder.startTable();
        String[] headers = {"功能模块", "用例数", "通过", "未通过"};
        for (String header : headers) {
            builder.insertCell();
            builder.getFont().setBold(true);
            builder.write(header);
        }
        builder.endRow();
        builder.getFont().setBold(false);
        Map<String, Integer> modules = new LinkedHashMap<String, Integer>();
        for (Case item : cases) {
            Integer n = modules.get(item.module);
            modules.put(item.module, n == null ? 1 : n + 1);
        }
        for (Map.Entry<String, Integer> entry : modules.entrySet()) {
            builder.insertCell();
            builder.write(entry.getKey());
            builder.insertCell();
            builder.write(String.valueOf(entry.getValue()));
            builder.insertCell();
            builder.write(String.valueOf(countModule(cases, entry.getKey(), "通过")));
            builder.insertCell();
            builder.write(String.valueOf(countModule(cases, entry.getKey(), "未通过")));
            builder.endRow();
        }
        builder.endTable();
        builder.insertBreak(BreakType.PAGE_BREAK);
    }

    private static void casePage(DocumentBuilder builder, Case item) throws Exception {
        builder.getFont().setSize(15);
        builder.getFont().setBold(true);
        builder.writeln("用例 " + item.id + "：" + item.title);
        builder.getFont().setBold(false);
        builder.getFont().setSize(10.5);
        builder.writeln("功能模块：" + item.module + "    功能点：" + item.point
                + "    优先级：" + item.priority);
        builder.writeln("前提条件：" + item.precondition);
        builder.writeln("操作步骤：");
        for (String step : item.steps.split("\n")) {
            builder.getParagraphFormat().setLeftIndent(18);
            builder.writeln(step);
            builder.getParagraphFormat().setLeftIndent(0);
        }
        builder.writeln("预期输出：" + item.expected);
        builder.writeln("测试方法：" + item.method);
        builder.getFont().setBold(true);
        builder.getFont().setColor("通过".equals(item.result)
                ? Color.decode("#2E7D32") : Color.decode("#C62828"));
        builder.writeln("测试结果：" + item.result);
        builder.getFont().setBold(false);
        builder.getFont().setColor(Color.BLACK);

        File image = new File(item.image);
        BufferedImage img = ImageIO.read(image);
        if (img == null) {
            throw new IllegalArgumentException("截图不存在或无法读取: " + image.getAbsolutePath());
        }
        double maxWidth = 16.5 * 28.35;
        double maxHeight = 13.5 * 28.35;
        double scale = Math.min(1.0,
                Math.min(maxWidth / img.getWidth(), maxHeight / img.getHeight()));
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.CENTER);
        builder.insertImage(image.getAbsolutePath(),
                img.getWidth() * scale, img.getHeight() * scale);
        builder.insertParagraph();
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.LEFT);
        builder.insertBreak(BreakType.PAGE_BREAK);
    }

    private static void headerFooter(DocumentBuilder builder) throws Exception {
        builder.moveToHeaderFooter(HeaderFooterType.HEADER_PRIMARY);
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.RIGHT);
        builder.getFont().setSize(9);
        builder.getFont().setColor(Color.GRAY);
        builder.writeln("组件测试报告");
        builder.moveToHeaderFooter(HeaderFooterType.FOOTER_PRIMARY);
        builder.getParagraphFormat().setAlignment(ParagraphAlignment.CENTER);
        builder.insertField("PAGE", "");
    }

    private static int countModule(List<Case> cases, String module, String result) {
        int count = 0;
        for (Case item : cases) {
            if (module.equals(item.module) && result.equals(item.result)) {
                count++;
            }
        }
        return count;
    }

    private static int count(List<Case> cases, String result) {
        int count = 0;
        for (Case item : cases) {
            if (result.equals(item.result)) {
                count++;
            }
        }
        return count;
    }

    static final class Case {
        int id;
        String module;
        String point;
        String title;
        String priority;
        String precondition;
        String steps;
        String expected;
        String method;
        String result;
        String image;
    }
}
