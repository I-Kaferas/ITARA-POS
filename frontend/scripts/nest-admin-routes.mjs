import fs from 'node:fs'

const path = new URL('../src/router/index.ts', import.meta.url)
let src = fs.readFileSync(path, 'utf8')

const startMarker = 'routes: ['
const start = src.indexOf(startMarker)
const end = src.indexOf('],\n})', start)
if (start < 0 || end < 0) {
  console.error('Could not find routes block')
  process.exit(1)
}

const before = src.slice(0, start + startMarker.length)
const after = src.slice(end) // starts with ],\n})
const routesBlock = src.slice(start + startMarker.length, end)

const routes = []
let i = 0
while (i < routesBlock.length) {
  while (i < routesBlock.length && /[\s,]/.test(routesBlock[i])) i++
  if (i >= routesBlock.length) break
  if (routesBlock[i] !== '{') {
    console.error('expected { at', i, JSON.stringify(routesBlock.slice(i, i + 40)))
    process.exit(1)
  }
  let depth = 0
  const startObj = i
  for (; i < routesBlock.length; i++) {
    const c = routesBlock[i]
    if (c === '{') depth++
    else if (c === '}') {
      depth--
      if (depth === 0) {
        i++
        routes.push(routesBlock.slice(startObj, i))
        break
      }
    }
  }
}

const guest = []
const admin = []
for (const r of routes) {
  if (
    r.includes("path: '/'") ||
    r.includes('meta: { guest: true }') ||
    r.includes("path: '/sign/") ||
    r.includes("path: '/login'") ||
    r.includes("path: '/forgot-password'") ||
    r.includes("path: '/reset-password'")
  ) {
    guest.push(r)
  } else if (r.includes("path: '/admin")) {
    admin.push(r)
  } else {
    guest.push(r)
  }
}

function toChild(r) {
  let out = r
  out = out.replace(/path: '\/admin'([,\n])/, "path: ''$1")
  out = out.replace(/path: '\/admin\//g, "path: '")
  // Children inherit requiresAuth from parent; keep meta if present.
  return out
    .split('\n')
    .map((line) => '        ' + line.trimEnd())
    .join('\n')
    .replace(/^\s+\n/, '')
}

const children = admin.map(toChild).join(',\n')
const guestOut = guest.map((r) => '    ' + r.trim()).join(',\n')

const nested = `
${guestOut},
    {
      path: '/admin',
      component: () => import('../components/layout/AdminLayout.vue'),
      meta: { requiresAuth: true },
      children: [
${children}
      ],
    }`

const next = before + nested + '\n  ' + after
fs.writeFileSync(path, next)
console.log(`nested ${admin.length} admin routes; ${guest.length} top-level routes`)
