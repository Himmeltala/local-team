import { spawnSync } from "node:child_process"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

const SKILLS = fileURLToPath(new URL("../skills/", import.meta.url))
const SCRIPTS = fileURLToPath(new URL("../hooks/scripts/", import.meta.url))
const GUARDS = ["svn-commit-guard.sh", "git-commit-guard.sh"]
const TIMEOUT = 60_000
const COMMIT = /(^|[\s;&|()])(git|svn)\s+commit\b/

function run(script, payload) {
  const result = spawnSync("bash", [join(SCRIPTS, script)], {
    input: JSON.stringify(payload),
    encoding: "utf8",
    timeout: TIMEOUT,
  })
  if (result.error) return { code: 0, stderr: "" }
  return { code: result.status ?? 0, stderr: result.stderr ?? "" }
}

export const plugin = async ({ directory }) => ({
  config: (cfg) => {
    cfg.skills ??= {}
    const paths = (cfg.skills.paths ??= [])
    if (!paths.includes(SKILLS)) paths.push(SKILLS)
  },
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return
    const command = output.args?.command
    if (typeof command !== "string" || !COMMIT.test(command)) return

    const payload = {
      tool_name: "Bash",
      cwd: output.args?.cwd ?? directory,
      tool_input: { command },
    }
    for (const script of GUARDS) {
      const result = run(script, payload)
      if (result.code === 2) throw new Error(result.stderr || "提交被拦下")
    }
  },
})
