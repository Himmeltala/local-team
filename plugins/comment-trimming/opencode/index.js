import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

const SKILLS = fileURLToPath(new URL("../skills/", import.meta.url))
const AGENT = fileURLToPath(new URL("../agents/comment-trimmer.md", import.meta.url))

function splitFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text)
  if (match === null) return { meta: {}, body: text }
  const meta = {}
  for (const line of match[1].split(/\r?\n/)) {
    const colon = line.indexOf(":")
    if (colon <= 0) continue
    const key = line.slice(0, colon).trim()
    if (key === "" || key.startsWith("#")) continue
    meta[key] = line.slice(colon + 1).trim().replace(/^["']|["']$/g, "")
  }
  return { meta, body: text.slice(match[0].length) }
}

export const plugin = async () => ({
  config: (cfg) => {
    cfg.skills ??= {}
    const paths = (cfg.skills.paths ??= [])
    if (!paths.includes(SKILLS)) paths.push(SKILLS)

    const { meta, body } = splitFrontmatter(readFileSync(AGENT, "utf8"))
    cfg.agent ??= {}
    cfg.agent["comment-trimmer"] = {
      description: meta.description,
      mode: "subagent",
      prompt: body,
    }
  },
})
