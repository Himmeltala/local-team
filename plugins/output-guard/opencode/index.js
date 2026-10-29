import { fileURLToPath } from "node:url"

const SKILLS = fileURLToPath(new URL("../skills/", import.meta.url))

export const plugin = async () => ({
  config: (cfg) => {
    cfg.skills ??= {}
    const paths = (cfg.skills.paths ??= [])
    if (!paths.includes(SKILLS)) paths.push(SKILLS)
  },
})
