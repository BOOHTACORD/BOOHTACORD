import { createRequire } from 'node:module'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'

const root = fileURLToPath(new URL('../../../', import.meta.url))
const require = createRequire(resolve(root, 'clients/web/package.json'))
const ts = require('typescript')
const { parse } = require('@vue/compiler-sfc')

export function importsOf(source, path) {
  const uris = []
  const scripts = path.endsWith('.vue')
    ? [parse(source, { filename: path }).descriptor].flatMap(d => [d.script?.content, d.scriptSetup?.content]).filter(Boolean)
    : [source]
  for (const script of scripts) {
    const ast = ts.createSourceFile(path + '.ts', script, ts.ScriptTarget.Latest, true)
    function visit(node) {
      if ((ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) && node.moduleSpecifier && ts.isStringLiteral(node.moduleSpecifier)) {
        uris.push(node.moduleSpecifier.text)
      } else if (ts.isCallExpression(node) && node.expression.kind === ts.SyntaxKind.ImportKeyword && ts.isStringLiteral(node.arguments[0])) {
        uris.push(node.arguments[0].text)
      }
      ts.forEachChild(node, visit)
    }
    visit(ast)
  }
  return uris
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const trackedPaths = roots => execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', ...roots], { cwd: root, encoding: 'utf8' })
    .split('\0')
    .filter(path => path && existsSync(resolve(root, path)))
  const paths = [...new Set([
    ...trackedPaths(['clients/web/src']),
    ...trackedPaths(['tools/audio/research_dfn_web/stage.mjs', 'tools/audio/research_dfn_web/build.py']),
    ...trackedPaths(['contracts']).filter(path => path.endsWith('.json')),
  ])]
  const result = Object.fromEntries(paths.map(path => [path, /\.(ts|vue|js)$/.test(path) ? importsOf(readFileSync(resolve(root, path), 'utf8'), path) : []]))
  process.stdout.write(JSON.stringify(result))
}
