import fs from 'node:fs'

const s = fs.readFileSync('src/router/index.ts', 'utf8')
console.log('has AdminLayout parent', s.includes("import('../components/layout/AdminLayout.vue)"))
console.log('child path products', s.includes("path: 'products'"))
console.log('bad absolute admin child', /path: '\/admin\//.test(s))
console.log('dashboard empty path', s.includes("path: ''"))
