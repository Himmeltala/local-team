/*
 * @Author: Himmeltala
 * @Date: 2026-10-29 15:08:00
 * @LastEditors: Himmeltala
 * @LastEditTime: 2026-10-29 15:08:00
 * @FilePath: \plugins\commit-guarding\lib\guard.js
 * @Description: 在 DSH 的 bash 调用前复跑 Claude 那两份提交闸门脚本。
 */
import { spawn } from 'node:child_process'
import { isAbsolute, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const SCRIPTS = ['svn-commit-guard.sh', 'git-commit-guard.sh']
const DIRECTORY = fileURLToPath(new URL('../hooks/scripts/', import.meta.url))
const TIMEOUT = 60_000

function run(script, payload) {
  return new Promise((done) => {
    const child = spawn('bash', [join(DIRECTORY, script)], { stdio: ['pipe', 'ignore', 'pipe'] })
    const timer = setTimeout(() => child.kill(), TIMEOUT)
    let stderr = ''
    child.stderr.setEncoding('utf8')
    child.stderr.on('data', (chunk) => { stderr += chunk })
    child.on('error', () => { clearTimeout(timer); done({ code: 0, stderr: '' }) })
    child.on('close', (code) => { clearTimeout(timer); done({ code: code ?? 0, stderr }) })
    child.stdin.end(JSON.stringify(payload))
  })
}

function baseDirectory(ctx, exec) {
  try {
    const service = ctx.get('workingDirectory')
    const session = exec.agent?.session
    if (service !== undefined && session !== undefined) return service.get(session)
  } catch {
    // 服务不可用时退回进程目录，闸门本身不能因此堵住调用。
  }
  return process.cwd()
}

function directory(ctx, exec) {
  const workdir = exec.arguments?.workdir
  const base = baseDirectory(ctx, exec)
  if (typeof workdir !== 'string' || workdir === '') return base
  return isAbsolute(workdir) ? workdir : resolve(base, workdir)
}

export function registerGuard(ctx) {
  ctx.on('tools/pre-execute', async (exec, next) => {
    if (exec.name !== 'bash') return next()
    const command = exec.arguments?.command
    if (typeof command !== 'string' || command.trim() === '') return next()
    const payload = {
      session_id: exec.agent?.session?.header?.id ?? '',
      hook_event_name: 'PreToolUse',
      tool_name: 'Bash',
      cwd: directory(ctx, exec),
      tool_input: exec.arguments,
    }
    for (const script of SCRIPTS) {
      const result = await run(script, payload)
      if (result.code === 2) {
        return { kind: 'deny', reason: result.stderr.trim() || '提交被提交闸门拦下' }
      }
    }
    return next()
  })
}
