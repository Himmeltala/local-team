/*
 * @Author: Himmeltala
 * @Date: 2026-10-29 16:02:00
 * @LastEditors: Himmeltala
 * @LastEditTime: 2026-10-29 16:02:00
 * @FilePath: \scripts\check-plugins.mjs
 * @Description: 校验八个插件的双端打包：版本一致、技能可列出、提交闸门可拦可放。
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const ROOT = fileURLToPath(new URL('..', import.meta.url))
let failures = 0

function check(condition, message) {
  if (condition) {
    console.log(`ok   ${message}`)
  } else {
    failures += 1
    console.log(`FAIL ${message}`)
  }
}

function fakeContext(provider, listener) {
  return {
    skills: { registerProvider: (factory) => { provider.value = factory() } },
    on: (event, handler) => { if (event === 'tools/pre-execute') listener.value = handler },
    get: (name) => name === 'workingDirectory' ? { get: () => ROOT } : undefined,
  }
}

async function runPlugin(plugin) {
  const dir = join(ROOT, 'plugins', plugin)
  const manifest = JSON.parse(readFileSync(join(dir, '.claude-plugin', 'plugin.json'), 'utf8'))
  const pkg = JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8'))

  check(pkg.version === manifest.version, `${plugin} 版本一致 ${pkg.version}`)
  check(pkg.name === `dsh-local-team-${plugin}`, `${plugin} 包名 ${pkg.name}`)
  check(pkg.dsh?.bundle?.patch === './cordis.patch.yml', `${plugin} 声明 dsh.bundle`)
  check(pkg.files?.includes('cordis.patch.yml') === true, `${plugin} 打包带 cordis.patch.yml`)

  const provider = {}
  const listener = {}
  const module = await import(pathToFileURL(join(dir, 'lib', 'index.js')).href)
  module.apply(fakeContext(provider, listener))

  const expected = readdirSync(join(dir, 'skills'), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort()
  const listed = (await provider.value.list()).map((skill) => skill.name).sort()
  check(JSON.stringify(listed) === JSON.stringify(expected), `${plugin} 技能齐全 ${listed.join(',')}`)

  const definition = await provider.value.get({ name: listed[0] })
  check(definition?.content?.length > 0, `${plugin} 正文可读 ${definition?.name}`)

  if (plugin === 'commit-guarding') {
    const exec = (command) => ({ name: 'bash', arguments: { command, description: 'check' }, agent: { session: { header: { id: 'check' } } } })
    const next = async () => ({ kind: 'allow' })
    const denied = await listener.value(exec('git commit -m "feat(login): 加个功能"'), next)
    const allowed = await listener.value(exec('ls -la'), next)
    check(denied.kind === 'deny', 'commit-guarding 闸门拦下带范围括号的提交')
    check(allowed.kind === 'allow', 'commit-guarding 闸门放行普通命令')
  }
}

const plugins = readdirSync(join(ROOT, 'plugins'), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort()

for (const plugin of plugins) await runPlugin(plugin)
console.log(failures === 0 ? `\n${plugins.length} 个插件全部通过` : `\n${failures} 项失败`)
process.exit(failures === 0 ? 0 : 1)
