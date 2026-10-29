import { existsSync, lstatSync, mkdirSync, readlinkSync, symlinkSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const REPO = resolve(fileURLToPath(new URL("..", import.meta.url)))
const SOURCE = join(REPO, "opencode", "index.js")
const DIR = join(homedir(), ".config", "opencode", "plugins")
const TARGET = join(DIR, "local-team.js")

function link() {
  try {
    return lstatSync(TARGET).isSymbolicLink() ? readlinkSync(TARGET) : null
  } catch {
    return null
  }
}

mkdirSync(DIR, { recursive: true })

const current = link()
if (current !== null) {
  if (resolve(dirname(TARGET), current) === SOURCE) {
    console.log(`已安装：${TARGET} -> ${SOURCE}`)
    process.exit(0)
  }
  console.error(`${TARGET} 已是指向别处的软链，未覆盖：${current}`)
  process.exit(1)
}

if (existsSync(TARGET)) {
  console.error(`${TARGET} 已存在且不是软链，未覆盖。`)
  process.exit(1)
}

symlinkSync(SOURCE, TARGET)
console.log(`已安装：${TARGET} -> ${SOURCE}`)
console.log("重启 opencode 后生效。")
