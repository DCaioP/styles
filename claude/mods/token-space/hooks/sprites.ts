import type { Body } from './cosmos'

/** The sprite's box in terminal cells; each cell holds two pixels stacked with half-blocks. */
export const SPRITE_COLUMNS = 14
export const SPRITE_ROWS = 4
/** The exhaust beside the thrust: three cells of flame and the rocket's nose. */
export const FLAME_COLUMNS = 4
/** The spinner's scene: one row of space with the rocket crossing it. */
export const SHIP_COLUMNS = 16

const CENTER_X = SPRITE_COLUMNS / 2
const CENTER_Y = SPRITE_ROWS

const DEFAULT = 0x01000000
const SPACE = 0x20
const UPPER_HALF = 0x2580
const LOWER_HALF = 0x2584
const SHADES = [0x2591, 0x2592, 0x2593] as const
const NOSE = 0x25b6
const STREAK = 0x2500
const HOT = [0xff3b00, 0xff9a00, 0xfff2a0] as const
const COLD = [0x0050ff, 0x00b8ff, 0xd0faff] as const
/** Single braille dots: a star anywhere inside its cell. */
const STAR_DOTS = [0x2801, 0x2802, 0x2804, 0x2808, 0x2810, 0x2820, 0x2840, 0x2880] as const

/** A pixel's color as 0xRRGGBB, or null where space shows through. */
type Pixel = number | null
type Shader = (x: number, y: number, t: number) => Pixel

function clamp(value: number, low: number, high: number): number {
  return Math.max(low, Math.min(high, value))
}

function channels(color: number): [number, number, number] {
  return [(color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff]
}

function rgb(r: number, g: number, b: number): number {
  return (Math.round(clamp(r, 0, 255)) << 16) | (Math.round(clamp(g, 0, 255)) << 8) | Math.round(clamp(b, 0, 255))
}

function mix(from: number, to: number, k: number): number {
  const a = channels(from)
  const b = channels(to)
  const w = clamp(k, 0, 1)

  return rgb(a[0] + (b[0] - a[0]) * w, a[1] + (b[1] - a[1]) * w, a[2] + (b[2] - a[2]) * w)
}

function shade(color: number, k: number): number {
  const [r, g, b] = channels(color)

  return rgb(r * k, g * k, b * k)
}

/** A stable pseudo-random value in [0, 1) for a lattice point. */
function hash(x: number, y: number): number {
  const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453

  return s - Math.floor(s)
}

/** Longitude and latitude of a pixel on a sphere of radius `r`, turned by `spin`. */
function surface(dx: number, dy: number, r: number, spin: number): { lon: number; lat: number } {
  const half = Math.sqrt(Math.max(r * r - dy * dy, 0.0001))

  return { lon: Math.asin(clamp(dx / half, -1, 1)) + spin, lat: dy / r }
}

/** Lit from the upper left, darker toward the far limb. */
function light(dx: number, dy: number, r: number): number {
  return 0.5 + 0.5 * clamp(-(dx / r) * 0.8 - (dy / r) * 0.35 + 0.35, -1, 1)
}

/** A small moon on a tilted orbit, hidden while it passes behind its planet. */
function moon(px: number, py: number, t: number, speed: number, r: number): Pixel {
  const a = t * speed
  const mx = CENTER_X + Math.cos(a) * 6.2
  const my = CENTER_Y + Math.sin(a) * 1.7
  const isBehind = Math.sin(a) < 0 && Math.hypot(px - CENTER_X, py - CENTER_Y) < r

  return !isBehind && Math.hypot(px - mx, py - my) < 0.8 ? 0xc9c9d6 : null
}

/** Smooth value noise in [0, 1): `hash` on the lattice, eased in between. */
function noise(x: number, y: number): number {
  const ix = Math.floor(x)
  const iy = Math.floor(y)
  const fx = x - ix
  const fy = y - iy
  const ux = fx * fx * (3 - 2 * fx)
  const uy = fy * fy * (3 - 2 * fy)
  const top = hash(ix, iy) + (hash(ix + 1, iy) - hash(ix, iy)) * ux
  const bottom = hash(ix, iy + 1) + (hash(ix + 1, iy + 1) - hash(ix, iy + 1)) * ux

  return top + (bottom - top) * uy
}

const SUN_RADIUS = 2.55
/** The corona stops short of the sprite's top and bottom, 4 pixels from the center. */
const CORONA_REACH = 1.35

/**
 * The Sun: a disc darkening toward its limb with granulation boiling across it,
 * and a corona that fades outward in fine, slowly shifting filaments.
 * (Same body as spacefetch's, which draws it at any scale.)
 */
const sun: Shader = (x, y, t) => {
  const dx = x + 0.5 - CENTER_X
  const dy = y + 0.5 - CENTER_Y
  const d = Math.hypot(dx, dy)
  const r = SUN_RADIUS + 0.05 * Math.sin(t * 0.25)

  if (d < r) {
    const limb = Math.sqrt(1 - (d / r) ** 2)
    const cells = noise(dx * 2.2 + t * 0.06, dy * 2.2 - t * 0.04)
    const heat = clamp(limb * 0.85 + (cells - 0.5) * 0.35, 0, 1)

    return heat > 0.55 ? mix(0xffd23a, 0xfffbe6, (heat - 0.55) / 0.45) : mix(0xe0480a, 0xffd23a, heat / 0.55)
  }

  const out = (d - r) / CORONA_REACH
  if (out >= 1) return null

  const angle = Math.atan2(dy, dx)
  const wisps = noise(angle * 4 + t * 0.05, d * 0.8 - t * 0.12) * 0.6 + noise(angle * 11 - t * 0.03, t * 0.08) * 0.4
  const glow = (1 - out) ** 1.6 * (0.45 + 0.75 * wisps)
  if (glow < 0.28) return null

  return mix(0x5a1800, 0xff9a1a, clamp((glow - 0.28) / 0.7, 0, 1))
}

/** Mercury to Mars: a rusty world turning, polar caps, and a moon going round. */
const rocky: Shader = (x, y, t) => {
  const px = x + 0.5
  const py = y + 0.5
  const dx = px - CENTER_X
  const dy = py - CENTER_Y
  const r = 3.2
  const moonlight = moon(px, py, t, 0.11, r)
  if (moonlight !== null) return moonlight
  if (Math.hypot(dx, dy) >= r) return null

  const { lon, lat } = surface(dx, dy, r, t * 0.07)
  const terrain = Math.sin(lon * 3.1) * Math.cos(lat * 4.2) + 0.6 * Math.sin(lon * 5.3 + lat * 2.1)
  const ground = terrain > 0.7 ? 0x8b2e0b : terrain > -0.2 ? 0xc1440e : 0xe27b58
  const color = Math.abs(lat) > 0.82 ? 0xf2e6dc : ground

  return shade(color, light(dx, dy, r))
}

/** Jupiter to Saturn: amber bands drifting under a cyan ring with a glint running round it. */
const gasGiant: Shader = (x, y, t) => {
  const dx = x + 0.5 - CENTER_X
  const dy = y + 0.5 - CENTER_Y
  const r = 2.7
  const tilt = dy - dx * 0.12
  const rho = Math.hypot(dx / 6.7, tilt / 1.5)
  const isRing = rho > 0.6 && rho < 1 && (rho < 0.79 || rho > 0.85)
  const glint = Math.cos(Math.atan2(tilt / 1.5, dx / 6.7) - t * 0.22) > 0.96
  const ring = glint ? 0xeaffff : mix(0x00e5ff, 0x00799e, (rho - 0.6) / 0.4)
  const d = Math.hypot(dx, dy)

  if (isRing && (tilt > 0 || d >= r)) return ring
  if (d >= r) return null

  const { lon, lat } = surface(dx, dy, r, t * 0.1)
  const band = Math.sin(lat * 7.5 + 0.35 * Math.sin(lon * 2))
  const color = band > 0.45 ? 0xf5deb3 : band > -0.35 ? 0xffbf00 : 0xb5651d

  return shade(color, 0.55 + 0.45 * Math.sqrt(1 - (d / r) ** 2))
}

/** Uranus to Neptune: deep blue bands, a dark storm and white streaks going round. */
const iceGiant: Shader = (x, y, t) => {
  const px = x + 0.5
  const py = y + 0.5
  const dx = px - CENTER_X
  const dy = py - CENTER_Y
  const r = 3.2
  const moonlight = moon(px, py, t, -0.09, r)
  if (moonlight !== null) return moonlight
  if (Math.hypot(dx, dy) >= r) return null

  const { lon, lat } = surface(dx, dy, r, t * 0.12)
  const phase = Math.atan2(Math.sin(lon), Math.cos(lon))
  let color = mix(0x1b3fa8, 0x2f6bff, 0.5 + 0.5 * Math.sin(lat * 5 + 0.4))
  if (Math.abs(phase - 0.6) < 0.4 && Math.abs(lat - 0.3) < 0.2) color = 0x0d1f5c
  if (Math.abs(lat + 0.45) < 0.15 && Math.sin(lon * 4) > 0.55) color = 0xdde8ff

  return shade(color, light(dx, dy, r))
}

/** The Kuiper Belt: a comet bobbing along, its tail streaming particles behind it. */
const comet: Shader = (x, y, t) => {
  const px = x + 0.5
  const py = y + 0.5
  const hx = 10.5 + 0.7 * Math.sin(t * 0.09)
  const hy = 3.5 + 0.6 * Math.sin(t * 0.13)
  const dx = px - hx
  const dy = py - hy
  const d = Math.hypot(dx, dy)

  if (d < 1) return 0xffffff
  if (d < 1.7) return 0xffb3ff
  if (dx >= 0 || Math.abs(dy) >= -dx * 0.32 + 0.6) return null

  const k = -dx / hx
  const particle = hash(Math.floor(px + t * 0.9), y)

  return particle > 0.3 + k * 0.55 ? mix(0xff00ff, 0x5a1a8c, k) : null
}

/**
 * The shadow, the photon ring hugging it, and the accretion disk around both.
 * Same body as spacefetch's, with the thin parts thickened to survive 14×8 pixels.
 */
const HORIZON = 1.9
const PHOTON_RING = 0.6
const DISK_INNER = 2.1
const DISK_OUTER = 7
/** The disk's tilt: how flat its ellipse looks from here. */
const DISK_TILT = 0.22
/** The far side of the disk, bent by the hole into an arc over the top. */
const ARC_WIDTH = 1
const CLUMPS = 3
const CLUMP_LIFE = 70

/**
 * The disk's own light at radius `rho` and angle `phi` of its plane: hot white
 * inside fading to deep red outside, turbulence the inner orbits shear into
 * spirals (they turn faster), and the side coming at us beamed brighter.
 */
function diskLight(rho: number, phi: number, t: number): Pixel {
  if (rho < DISK_INNER || rho > DISK_OUTER) return null

  const heat = 1 - (rho - DISK_INNER) / (DISK_OUTER - DISK_INNER)
  const orbit = phi - t * 0.5 * (DISK_INNER / rho) ** 1.5
  const streaks = noise(Math.cos(orbit) * 2.6 + 9, Math.sin(orbit) * 2.6 + rho * 2.4)
  const beaming = 1 + 0.5 * -Math.cos(phi)
  const glow = heat ** 0.8 * (0.45 + 0.75 * streaks) * beaming
  // The outer edge frays instead of ending in a clean ellipse.
  if (glow < 0.12) return null

  const color =
    glow > 0.8 ? mix(0xffd27a, 0xfff6e8, (glow - 0.8) / 0.5)
    : glow > 0.4 ? mix(0xff6a00, 0xffd27a, (glow - 0.4) / 0.4)
    : mix(0x4a0800, 0xff6a00, (glow - 0.12) / 0.28)

  // A hint of blue-white on the approaching side, of ember on the receding one.
  return beaming > 1.2 ? mix(color, 0xe8f0ff, (beaming - 1.2) * 0.35) : color
}

/** Hot clumps of matter spiralling in, flaring white, gone at the horizon. */
function infall(u: number, v: number, t: number): Pixel {
  for (let k = 0; k < CLUMPS; k += 1) {
    const shifted = t + k * (CLUMP_LIFE / CLUMPS)
    const cycle = Math.floor(shifted / CLUMP_LIFE)
    const age = (shifted - cycle * CLUMP_LIFE) / CLUMP_LIFE
    const rho = DISK_OUTER * 0.85 - (DISK_OUTER * 0.85 - HORIZON) * age ** 1.6
    const phi = hash(cycle, k) * Math.PI * 2 + age * 9
    const cu = Math.cos(phi) * rho
    const cv = Math.sin(phi) * rho
    if (Math.hypot(u - cu, (v - cv) * 0.6) < 0.55 + 0.2 * age) return mix(0xffb070, 0xffffff, age)
  }

  return null
}

/**
 * The Black Hole, after Gargantua: a black shadow ringed by photons, the near
 * half of a tilted disk crossing in front of it, the far half lensed into an arc
 * over the top (and faintly under), all of it turning, and clumps falling in.
 */
const blackHole: Shader = (x, y, t) => {
  const dx = x + 0.5 - CENTER_X
  const dy = y + 0.5 - CENTER_Y
  const d = Math.hypot(dx, dy)
  const angle = Math.atan2(dy, dx)
  // The disk's own plane: x as is, y stretched back out of the tilt.
  const v = dy / DISK_TILT
  const rho = Math.hypot(dx, v)
  const phi = Math.atan2(v, dx)

  // Near half of the disk, in front of everything.
  if (dy >= 0) {
    const clump = infall(dx, v, t)
    if (clump !== null && rho > DISK_INNER * 0.7) return clump
    const near = diskLight(rho, phi, t)
    if (near !== null) return near
  }

  if (d < HORIZON) return 0x000000

  const ringOut = d - HORIZON
  if (ringOut < PHOTON_RING) {
    const shimmer = 0.75 + 0.25 * Math.sin(angle * 5 - t * 1.1) * Math.sin(angle * 2 + t * 0.4)
    const side = 1 + 0.25 * -Math.cos(angle)

    return mix(0xff8a2a, 0xfff4dc, clamp(shimmer * side - 0.3, 0, 1))
  }

  // The far half, lensed: each radius of the arc shows a ring of the disk behind.
  const arcOut = (ringOut - PHOTON_RING) / ARC_WIDTH
  if (arcOut < 1 && dy < 0.2) {
    const seen = diskLight(DISK_INNER + arcOut * (DISK_OUTER - DISK_INNER) * 0.4, angle, t)
    if (seen !== null) return shade(seen, 1 - arcOut * 0.6)
  }

  // The far half of the disk itself, where the shadow does not hide it.
  if (dy < 0) {
    const far = diskLight(rho, phi, t)
    if (far !== null) return shade(far, 0.8)
  }

  return null
}

const SHADERS: Record<Body, Shader> = { sun, rocky, gas: gasGiant, ice: iceGiant, comet, hole: blackHole }

/** A background star for an empty cell, drifting left a column every four frames and twinkling. */
function star(column: number, row: number, t: number): [number, number] | null {
  const drift = column + Math.floor(t / 4)
  const seed = hash(drift, row * 7 + 3)
  if (seed > 0.11) return null

  const dot = STAR_DOTS[Math.floor(hash(drift, row + 11) * STAR_DOTS.length)]!
  const twinkle = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * 0.6 + seed * 60))

  return [dot, shade(0xc8d0ff, twinkle)]
}

function encode(words: Uint32Array): string {
  const bytes = new Uint8Array(words.buffer)
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)

  return btoa(binary)
}

/** One frame of a body as Raster cells: two pixels per cell, stars where both are empty. */
export function spriteCells(body: Body, t: number): string {
  const shader = SHADERS[body]
  const words = new Uint32Array(SPRITE_COLUMNS * SPRITE_ROWS * 3)

  for (let row = 0; row < SPRITE_ROWS; row += 1) {
    for (let column = 0; column < SPRITE_COLUMNS; column += 1) {
      const top = shader(column, row * 2, t)
      const bottom = shader(column, row * 2 + 1, t)
      const cell =
        top !== null ? [UPPER_HALF, top, bottom ?? DEFAULT]
        : bottom !== null ? [LOWER_HALF, bottom, DEFAULT]
        : (() => {
            const lit = star(column, row, t)

            return lit === null ? [SPACE, DEFAULT, DEFAULT] : [lit[0], lit[1], DEFAULT]
          })()
      words.set(cell, (row * SPRITE_COLUMNS + column) * 3)
    }
  }

  return encode(words)
}

/** The exhaust flickering behind the nose: hot and forward for thrust, cold and reversed for a retro-burn. */
export function flameCells(isRetro: boolean, t: number): string {
  const palette = isRetro ? COLD : HOT
  const words = new Uint32Array(FLAME_COLUMNS * 3)

  for (let i = 0; i < 3; i += 1) {
    words.set(flame(palette, i, t), (isRetro ? 3 - i : i) * 3)
  }
  words.set([NOSE, isRetro ? 0x9fd8ff : 0xe8e8f0, DEFAULT], (isRetro ? 0 : 3) * 3)

  return encode(words)
}

/** The spinner's frame: stars streaking past a rocket that surges forward and drifts back, its nose in `hull`. */
export function shipCells(t: number, hull: number): string {
  const words = new Uint32Array(SHIP_COLUMNS * 3)

  for (let column = 0; column < SHIP_COLUMNS; column += 1) {
    const seed = hash(column + Math.floor(t * 1.5), 5)
    const glyph = seed < 0.08 ? STREAK : STAR_DOTS[Math.floor(seed * 100) % STAR_DOTS.length]!
    words.set(seed < 0.22 ? [glyph, shade(0xc8d0ff, 0.35 + seed * 2.5), DEFAULT] : [SPACE, DEFAULT, DEFAULT], column * 3)
  }

  const nose = 8 + Math.round(3 * Math.sin(t * 0.12))
  for (let i = 0; i < 3; i += 1) words.set(flame(HOT, i, t), (nose - 3 + i) * 3)
  words.set([NOSE, hull, DEFAULT], nose * 3)

  return encode(words)
}

/** One cell of exhaust, `i` from the far end (0) to the nozzle (2), flickering frame to frame. */
function flame(palette: readonly [number, number, number], i: number, t: number): [number, number, number] {
  const flicker = hash(i, t)
  const glyph = SHADES[clamp(i + (flicker > 0.6 ? 1 : flicker < 0.25 ? -1 : 0), 0, 2)]!

  return [glyph, shade(palette[i as 0 | 1 | 2], 0.7 + 0.3 * flicker), DEFAULT]
}

/** The effort meter: one star per level, low to max. */
export const EFFORT_COLUMNS = 5
const STAR_FULL = 0x2605
const STAR_EMPTY = 0x2606
const STAR_SPARK = 0x2726
const EFFORT_VIOLET = 0xc792ea
/** At max the stars burn through a supernova, from white-hot to violet. */
const SUPERNOVA = [0xffffff, 0xfff2a0, 0xffb000, 0xff5a8c, 0xc792ea, 0x7aa2ff] as const

/**
 * The effort as stars, `rank` the lit ones (0 to 4) or -1 for none known. Below
 * max they glow softly in violet; at max a supernova runs through them and a
 * spark jumps from star to star.
 */
export function effortCells(rank: number, t: number): string {
  const words = new Uint32Array(EFFORT_COLUMNS * 3)
  const isMax = rank === EFFORT_COLUMNS - 1

  for (let i = 0; i < EFFORT_COLUMNS; i += 1) {
    if (i > rank) {
      words.set([STAR_EMPTY, shade(EFFORT_VIOLET, 0.45), DEFAULT], i * 3)
      continue
    }
    if (!isMax) {
      words.set([STAR_FULL, shade(EFFORT_VIOLET, 0.8 + 0.2 * Math.sin(t * 0.25 + i)), DEFAULT], i * 3)
      continue
    }
    const wave = (t * 0.35 + i * 0.9) % SUPERNOVA.length
    const from = SUPERNOVA[Math.floor(wave)]!
    const to = SUPERNOVA[(Math.floor(wave) + 1) % SUPERNOVA.length]!
    const isSpark = Math.floor(t / 2) % EFFORT_COLUMNS === i
    words.set([isSpark ? STAR_SPARK : STAR_FULL, isSpark ? 0xffffff : mix(from, to, wave % 1), DEFAULT], i * 3)
  }

  return encode(words)
}
