// Plays the six zones side by side in this terminal, in true color: `bun scripts/preview.ts [seconds]`.
import type { Body } from '../hooks/cosmos'
import { EFFORT_COLUMNS, FLAME_COLUMNS, SHIP_COLUMNS, SPRITE_COLUMNS, SPRITE_ROWS, effortCells, flameCells, shipCells, spriteCells } from '../hooks/sprites'

const BODIES: readonly [Body, string][] = [
  ['sun', 'Solar Core'],
  ['rocky', 'Inner Planets'],
  ['gas', 'Gas Giants'],
  ['ice', 'Ice Giants'],
  ['comet', 'Kuiper Belt'],
  ['hole', 'Black Hole'],
]
const DEFAULT = 0x01000000
const GAP = '  '

function words(cells: string): Uint32Array {
  const binary = atob(cells)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i)

  return new Uint32Array(bytes.buffer)
}

function paint(grid: Uint32Array, columns: number, row: number): string {
  let line = ''
  for (let column = 0; column < columns; column += 1) {
    const i = (row * columns + column) * 3
    const [glyph, fg, bg] = [grid[i]!, grid[i + 1]!, grid[i + 2]!]
    const fore = fg === DEFAULT ? '\x1b[39m' : `\x1b[38;2;${(fg >> 16) & 255};${(fg >> 8) & 255};${fg & 255}m`
    const back = bg === DEFAULT ? '\x1b[49m' : `\x1b[48;2;${(bg >> 16) & 255};${(bg >> 8) & 255};${bg & 255}m`
    line += fore + back + String.fromCodePoint(glyph)
  }

  return line + '\x1b[0m'
}

const seconds = Number(process.argv[2] ?? 10)
const height = SPRITE_ROWS + 4

for (let frame = 0; frame < seconds * 8; frame += 1) {
  const grids = BODIES.map(([body]) => words(spriteCells(body, frame)))
  const lines = [BODIES.map(([, name]) => name.padEnd(SPRITE_COLUMNS)).join(GAP)]
  for (let row = 0; row < SPRITE_ROWS; row += 1) {
    lines.push(grids.map(grid => paint(grid, SPRITE_COLUMNS, row)).join(GAP))
  }
  lines.push(
    `${paint(words(flameCells(false, frame)), FLAME_COLUMNS, 0)} thrust   ${paint(words(flameCells(true, frame)), FLAME_COLUMNS, 0)} retro-burn`,
  )
  lines.push(`${paint(words(shipCells(frame, 0x2f6bff)), SHIP_COLUMNS, 0)} Orbitando…  0:${String(Math.floor(frame / 8) % 60).padStart(2, '0')} · 59% do contexto`)
  lines.push(['low', 'medium', 'high', 'xhigh', 'max'].map((name, rank) => `${paint(words(effortCells(rank, frame)), EFFORT_COLUMNS, 0)} ${name.padEnd(7)}`).join('  '))
  process.stdout.write((frame === 0 ? '' : `\x1b[${height}A`) + lines.map(line => `\x1b[2K${line}`).join('\n') + '\n')
  await Bun.sleep(125)
}
