import fs from 'node:fs'
import path from 'node:path'
import zlib from 'node:zlib'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const svgRoot = path.resolve(root, '..', 'frontend', 'public')

const SILVER = [0x7d, 0x9a, 0xaf, 255]
const GOLD = [0xe3, 0x9b, 0x2b, 255]
const TILE = [0x1a, 0x22, 0x2a, 255]

function cubic(p0, p1, p2, p3, steps) {
  const points = []
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const u = 1 - t
    const x =
      u * u * u * p0[0] +
      3 * u * u * t * p1[0] +
      3 * u * t * t * p2[0] +
      t * t * t * p3[0]
    const y =
      u * u * u * p0[1] +
      3 * u * u * t * p1[1] +
      3 * u * t * t * p2[1] +
      t * t * t * p3[1]
    points.push([x, y])
  }
  return points
}

function relativeCubics(start, specs) {
  let [x, y] = start
  const points = [[x, y]]
  for (const [dx1, dy1, dx2, dy2, dx, dy] of specs) {
    const p0 = [x, y]
    const p1 = [x + dx1, y + dy1]
    const p2 = [x + dx2, y + dy2]
    const p3 = [x + dx, y + dy]
    const sampled = cubic(p0, p1, p2, p3, 24)
    points.push(...sampled.slice(1))
    x = p3[0]
    y = p3[1]
  }
  return points
}

const helmet = relativeCubics(
  [24, 8.5],
  [
    [-5.2, 0, -9.2, 4, -9.2, 9.1],
    [0, 3.1, 1.5, 5.4, 3.4, 7.1],
    [0.9, 0.8, 1.5, 1.6, 1.8, 2.6],
    [0.2, 0.6, 0.3, 1.2, 0.3, 1.9],
  ],
)
helmet.push([helmet.at(-1)[0] + 7.4, helmet.at(-1)[1]])
helmet.push(
  ...relativeCubics(helmet.at(-1), [
    [0, -0.7, 0.1, -1.3, 0.3, -1.9],
    [0.3, -1, 0.9, -1.8, 1.8, -2.6],
    [1.9, -1.7, 3.4, -4, 3.4, -7.1],
    [0, -5.1, -4, -9.1, -9.2, -9.1],
  ]).slice(1),
)

const goldLeft = relativeCubics(
  [24, 16.4],
  [[-2.1, 0.4, -3.4, 1.6, -3.4, 3.2]],
)
const goldRight = relativeCubics(
  [24, 16.4],
  [[2.1, 0.4, 3.4, 1.6, 3.4, 3.2]],
)

function render(size) {
  const ss = 4
  const canvas = size * ss
  const scale = canvas / 48
  const buf = new Uint8ClampedArray(canvas * canvas * 4)

  function stamp(cx, cy, radius, color) {
    const r = Math.ceil(radius)
    const x0 = Math.max(0, Math.floor(cx - r))
    const y0 = Math.max(0, Math.floor(cy - r))
    const x1 = Math.min(canvas - 1, Math.ceil(cx + r))
    const y1 = Math.min(canvas - 1, Math.ceil(cy + r))
    const r2 = radius * radius
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const dx = x + 0.5 - cx
        const dy = y + 0.5 - cy
        if (dx * dx + dy * dy <= r2) {
          const i = (y * canvas + x) * 4
          buf[i] = color[0]
          buf[i + 1] = color[1]
          buf[i + 2] = color[2]
          buf[i + 3] = color[3]
        }
      }
    }
  }

  function fillRoundedRect(rx) {
    const radius = rx * scale
    for (let y = 0; y < canvas; y++) {
      for (let x = 0; x < canvas; x++) {
        const px = x + 0.5
        const py = y + 0.5
        let cx = px
        let cy = py
        if (px < radius) cx = radius
        else if (px > canvas - radius) cx = canvas - radius
        if (py < radius) cy = radius
        else if (py > canvas - radius) cy = canvas - radius
        const dx = px - cx
        const dy = py - cy
        if (dx * dx + dy * dy <= radius * radius) {
          const i = (y * canvas + x) * 4
          buf[i] = TILE[0]
          buf[i + 1] = TILE[1]
          buf[i + 2] = TILE[2]
          buf[i + 3] = 255
        }
      }
    }
  }

  function stroke(points, width, color) {
    const radius = (width / 2) * scale
    for (let i = 1; i < points.length; i++) {
      const [x0, y0] = points[i - 1]
      const [x1, y1] = points[i]
      const dist = Math.hypot(x1 - x0, y1 - y0) * scale
      const steps = Math.max(1, Math.ceil(dist / Math.max(0.6, radius * 0.35)))
      for (let s = 0; s <= steps; s++) {
        const t = s / steps
        stamp(
          (x0 + (x1 - x0) * t) * scale,
          (y0 + (y1 - y0) * t) * scale,
          radius,
          color,
        )
      }
    }
  }

  fillRoundedRect(10)
  stroke(helmet, 1.7, SILVER)
  stroke(
    [
      [20.2, 32.2],
      [27.8, 32.2],
    ],
    1.5,
    SILVER,
  )
  stroke(
    [
      [21.1, 34.8],
      [26.9, 34.8],
    ],
    1.5,
    SILVER,
  )
  stroke(
    [
      [24, 14.2],
      [24, 20.4],
    ],
    1.6,
    GOLD,
  )
  stroke(goldLeft, 1.5, GOLD)
  stroke(goldRight, 1.5, GOLD)
  for (const [cx, cy] of [
    [20.4, 16.2],
    [27.6, 16.2],
    [24, 22.6],
  ]) {
    stamp(cx * scale, cy * scale, 1.15 * scale, GOLD)
  }

  const out = Buffer.alloc(size * size * 4)
  const area = ss * ss
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0
      let g = 0
      let b = 0
      let a = 0
      for (let oy = 0; oy < ss; oy++) {
        for (let ox = 0; ox < ss; ox++) {
          const i = ((y * ss + oy) * canvas + (x * ss + ox)) * 4
          r += buf[i]
          g += buf[i + 1]
          b += buf[i + 2]
          a += buf[i + 3]
        }
      }
      const o = (y * size + x) * 4
      out[o] = Math.round(r / area)
      out[o + 1] = Math.round(g / area)
      out[o + 2] = Math.round(b / area)
      out[o + 3] = Math.round(a / area)
    }
  }
  return out
}

function crc32(buffer) {
  let c = ~0
  for (let i = 0; i < buffer.length; i++) {
    c ^= buffer[i]
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    }
  }
  return ~c >>> 0
}

function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data])
  const out = Buffer.alloc(12 + data.length)
  out.writeUInt32BE(data.length, 0)
  body.copy(out, 4)
  out.writeUInt32BE(crc32(body), 4 + body.length)
  return out
}

function encodePng(size, rgba) {
  const raw = Buffer.alloc((size * 4 + 1) * size)
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4)
  }
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8
  ihdr[9] = 6
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

function buildIco(images) {
  const count = images.length
  const headerSize = 6 + count * 16
  let offset = headerSize
  const entries = []
  for (const { size, png } of images) {
    const entry = Buffer.alloc(16)
    entry.writeUInt8(size >= 256 ? 0 : size, 0)
    entry.writeUInt8(size >= 256 ? 0 : size, 1)
    entry.writeUInt16LE(1, 4)
    entry.writeUInt16LE(32, 6)
    entry.writeUInt32LE(png.length, 8)
    entry.writeUInt32LE(offset, 12)
    entries.push(entry)
    offset += png.length
  }
  const header = Buffer.alloc(6)
  header.writeUInt16LE(0, 0)
  header.writeUInt16LE(1, 2)
  header.writeUInt16LE(count, 4)
  return Buffer.concat([header, ...entries, ...images.map((image) => image.png)])
}

function writePng(file, size) {
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, encodePng(size, render(size)))
}

const brandSvg = fs.readFileSync(path.join(svgRoot, 'brand-mark.svg'), 'utf8')
if (!brandSvg.includes('#1a222a') || !brandSvg.includes('#e39b2b')) {
  throw new Error('brand-mark.svg does not match the expected ITARA mark')
}

const icoSizes = [16, 24, 32, 48, 64, 128, 256]
const icoImages = icoSizes.map((size) => ({
  size,
  png: encodePng(size, render(size)),
}))
const icoPath = path.join(root, 'windows', 'runner', 'resources', 'app_icon.ico')
fs.writeFileSync(icoPath, buildIco(icoImages))

writePng(path.join(root, 'assets', 'brand', 'itara_mark.png'), 256)

const androidLaunch = {
  mdpi: 96,
  hdpi: 144,
  xhdpi: 192,
  xxhdpi: 288,
  xxxhdpi: 384,
}
const androidLauncher = {
  mdpi: 48,
  hdpi: 72,
  xhdpi: 96,
  xxhdpi: 144,
  xxxhdpi: 192,
}
for (const [density, size] of Object.entries(androidLaunch)) {
  writePng(
    path.join(root, 'android', 'app', 'src', 'main', 'res', `drawable-${density}`, 'launch_image.png'),
    size,
  )
}
for (const [density, size] of Object.entries(androidLauncher)) {
  writePng(
    path.join(root, 'android', 'app', 'src', 'main', 'res', `mipmap-${density}`, 'ic_launcher.png'),
    size,
  )
}

console.log(`wrote ${icoPath}`)
