import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics2D;
import java.awt.GraphicsEnvironment;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

/**
 * 把命令与终端输出渲染成纯黑框截图。
 *
 * <p>用法：java TerminalShot command.txt output.txt shot.png</p>
 * <p>截图只含命令与输出，不加标题栏、模块名、结果底栏。</p>
 * <p>依赖 JDK 8+ 与 CJK 等宽字体（Noto Sans Mono CJK SC 或 WenQuanYi Micro Hei Mono）。</p>
 */
public final class TerminalShot {

    private static final int WIDTH = 1200;
    private static final int LINE_HEIGHT = 29;
    private static final int PADDING = 30;
    private static final Font MONO = pickMono();

    private static Font pickMono() {
        String[] candidates = {"Noto Sans Mono CJK SC", "WenQuanYi Micro Hei Mono"};
        String[] available = GraphicsEnvironment.getLocalGraphicsEnvironment()
                .getAvailableFontFamilyNames();
        for (String candidate : candidates) {
            for (String name : available) {
                if (candidate.equals(name)) {
                    return new Font(candidate, Font.PLAIN, 20);
                }
            }
        }
        return new Font("Monospaced", Font.PLAIN, 20);
    }

    private TerminalShot() {
    }

    public static void main(String[] args) throws Exception {
        String command = read(new File(args[0]));
        String output = read(new File(args[1]));
        BufferedImage image = render(command, output);
        ImageIO.write(image, "png", new File(args[2]));
    }

    static BufferedImage render(String command, String output) {
        List<String> commands = wrap(command, WIDTH - 80);
        List<String> outputs = wrap(output, WIDTH - 80);
        int maxOutputLines = 40;
        if (outputs.size() > maxOutputLines) {
            int cut = outputs.size() - maxOutputLines + 1;
            List<String> limited = new ArrayList<String>(outputs.subList(0, maxOutputLines - 1));
            limited.add("...（截断 " + cut + " 行）");
            outputs = limited;
        }
        int height = PADDING * 2 + (commands.size() + outputs.size()) * LINE_HEIGHT;
        BufferedImage image = new BufferedImage(WIDTH, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setColor(Color.BLACK);
        g.fillRect(0, 0, WIDTH, height);
        g.setFont(MONO);

        int y = PADDING + LINE_HEIGHT;
        for (int i = 0; i < commands.size(); i++) {
            g.setColor(new Color(0x6A9955));
            g.drawString((i == 0 ? "$ " : "  ") + commands.get(i), 36, y);
            y += LINE_HEIGHT;
        }
        for (String line : outputs) {
            g.setColor(isError(line) ? new Color(0xF48771) : new Color(0xD4D4D4));
            g.drawString(line, 36, y);
            y += LINE_HEIGHT;
        }
        g.dispose();
        return image;
    }

    private static boolean isError(String line) {
        return line.startsWith("[ERROR]")
                || line.contains("Caused by")
                || line.contains("Exception")
                || line.contains("转换失败");
    }

    private static List<String> wrap(String text, int maxWidth) {
        List<String> lines = new ArrayList<String>();
        BufferedImage probe = new BufferedImage(10, 10, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = probe.createGraphics();
        g.setFont(MONO);
        FontMetrics fm = g.getFontMetrics();
        for (String raw : safe(text).split("\n", -1)) {
            if (raw.isEmpty()) {
                lines.add("");
                continue;
            }
            StringBuilder line = new StringBuilder();
            for (int i = 0; i < raw.length(); i++) {
                char ch = raw.charAt(i);
                if (line.length() > 0 && fm.stringWidth(line.toString() + ch) > maxWidth) {
                    lines.add(line.toString());
                    line.setLength(0);
                }
                line.append(ch);
            }
            lines.add(line.toString());
        }
        g.dispose();
        return lines;
    }

    private static String safe(String text) {
        return text == null ? "" : text;
    }

    private static String read(File file) throws Exception {
        return new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
    }
}
