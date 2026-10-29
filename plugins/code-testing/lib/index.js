/*
 * @Author: Himmeltala
 * @Date: 2026-10-29 15:12:00
 * @LastEditors: Himmeltala
 * @LastEditTime: 2026-10-29 15:12:00
 * @FilePath: \plugins\code-testing\lib\index.js
 * @Description: 把插件内的技能目录注册为 DSH 技能来源。
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const PROVIDER = 'dsh-local-team-code-testing'
const SKILLS = fileURLToPath(new URL('../skills/', import.meta.url))
const RANK = 600
const SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

function splitFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text)
  if (match === null) return { meta: {}, body: text }
  const meta = {}
  for (const line of match[1].split(/\r?\n/)) {
    const colon = line.indexOf(':')
    if (colon <= 0) continue
    const key = line.slice(0, colon).trim()
    if (key === '' || key.startsWith('#')) continue
    meta[key] = line.slice(colon + 1).trim()
  }
  return { meta, body: text.slice(match[0].length) }
}

function discovered() {
  let entries
  try {
    entries = readdirSync(SKILLS, { withFileTypes: true })
  } catch {
    return []
  }
  const skills = []
  for (const entry of entries) {
    if (!entry.isDirectory()) continue
    const dir = join(SKILLS, entry.name)
    let text
    try {
      text = readFileSync(join(dir, 'SKILL.md'), 'utf8')
    } catch {
      continue
    }
    const { meta, body } = splitFrontmatter(text)
    const name = meta.name || entry.name
    if (!SKILL_NAME.test(name) || meta.description === undefined) continue
    skills.push({
      name,
      description: meta.description,
      invocation: {
        modelInvocable: meta['disable-model-invocation'] !== 'true',
        userInvocable: meta['user-invocable'] !== 'false',
      },
      dir,
      body,
    })
  }
  return skills.sort((a, b) => a.name.localeCompare(b.name))
}

function summary(skill) {
  return {
    name: skill.name,
    description: skill.description,
    invocation: skill.invocation,
    provider: PROVIDER,
    source: 'bundled',
    resourceBase: { kind: 'directory', path: skill.dir },
  }
}

export const name = PROVIDER
export const inject = ['skills']

export function apply(ctx) {
  ctx.skills.registerProvider(() => ({
    name: PROVIDER,
    async list() {
      return discovered().map(skill => ({ ...summary(skill), rank: RANK, locator: skill.name }))
    },
    async get(candidate) {
      const skill = discovered().find(item => item.name === candidate.name)
      if (skill === undefined) return undefined
      return { ...summary(skill), content: skill.body }
    },
  }))
}
