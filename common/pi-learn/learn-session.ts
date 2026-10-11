import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const course = path.join(os.homedir(), "Repos", "python-scraping-learning");

function inCourse(cwd: string): boolean {
  const resolved = path.resolve(cwd);
  return resolved === course || resolved.startsWith(course + path.sep);
}

export default function learnSession(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const cwd = ctx.cwd || process.cwd();
    if (!inCourse(cwd)) return;

    const day = new Date().toISOString().slice(0, 10);
    const file = path.join(course, "notes", "sessions", `${day}.md`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (!fs.existsSync(file)) {
      fs.writeFileSync(file, `# Python 爬虫学习 ${day}\n\n`, "utf8");
    }

    ctx.ui.setStatus(
      "course",
      ctx.ui.theme.fg("accent", "Python scraping tutor"),
    );
    ctx.ui.notify(`今日笔记已就绪。镜像本会话请运行: /md-log ${file}`, "info");
  });
}
