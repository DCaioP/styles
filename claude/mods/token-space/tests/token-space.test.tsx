import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { Body } from '../hooks/cosmos'
import { SHIP_COLUMNS, SPRITE_COLUMNS, SPRITE_ROWS, effortCells, flameCells, shipCells, spriteCells } from '../hooks/sprites'

const WINDOW = 200_000
const BODIES: readonly Body[] = ['sun', 'rocky', 'gas', 'ice', 'comet', 'hole']

function band(bodyColumns: number) {
  return {
    plugin: 'token-space',
    component: 'AbovePrompt' as const,
    props: {
      hasSurvey: false,
      isWorking: false,
      maxRows: 10,
      bodyColumns,
      scroll: { offset: 0, bodyRows: 9 },
      view: {},
    },
  }
}

/** The engine beneath the plugin: a context window whose fill the test sets, and the commands it ran. */
function cosmos(on: On) {
  const fill = { tokens: undefined as number | undefined, commands: [] as (readonly string[])[] }
  on('process.run', ($, e) => {
    fill.commands.push(e.argv)

    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('session.usage', () => ({
    value: { startedAt: 0, context: { tokens: fill.tokens, window: WINDOW }, rateLimits: [] },
  }))
  on('turn.complete', () => ({ text: '' }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('turn.start', ($, e) => ({ turnId: e.turnId }))

  return fill
}

const TURN = { answer: '', durationMs: 1, isAborted: false, reason: 'answer' as const }

function spinner(mode: 'thinking' | 'tool-use', message: string | null = null) {
  return {
    plugin: 'token-space',
    component: 'Spinner' as const,
    props: { word: 'Sauteing', message, suffix: '…', mode },
  }
}

/** The code points of a Raster's cells, every third word. */
function glyphs(cells: string): number[] {
  const binary = atob(cells)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i)
  const words = new Uint32Array(bytes.buffer)

  return Array.from(words).filter((_, i) => i % 3 === 0)
}

describe('token-space on the terminal', () => {
  test('the band draws the zone as ANSI art beside its telemetry', async ($, on) => {
    const fill = cosmos(on)
    fill.tokens = 20_000
    await $.turn.complete({ ...TURN, turnId: 't1' })
    fill.tokens = 118_300
    await $.turn.complete({ ...TURN, turnId: 't2' })

    const ui = await $.ui.mount({ ...band(120), surface: 'terminal' })
    expect(await ui.find({ type: 'Raster', key: 'sprite' })).toBeDefined()
    expect(await ui.find({ type: 'Raster', key: 'flame' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /🧊|🪐|☀️|🚀/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'Ice Giants' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Uranus-Neptune' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '59%' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '118.3k / 200k' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'telemetry ▁▅' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '+98.3k thrust' })).toBeDefined()
    await ui.unmount()
  })

  test('a compaction reads as a retro-burn, and a narrow band sheds the map strip', async ($, on) => {
    const fill = cosmos(on)
    fill.tokens = 150_000
    await $.turn.complete({ ...TURN, turnId: 't1' })
    fill.tokens = 70_000
    await $.turn.complete({ ...TURN, turnId: 't2' })

    const wide = await $.ui.mount({ ...band(120), surface: 'terminal' })
    expect(await wide.find({ type: 'Text', text: 'Gas Giants' })).toBeDefined()
    expect(await wide.find({ type: 'Text', text: '−80k retro-burn' })).toBeDefined()
    expect(await wide.find({ type: 'Text', text: /35% █+░+/ })).toBeDefined()
    await wide.unmount()

    const narrow = await $.ui.mount({ ...band(50), surface: 'terminal' })
    expect(await narrow.find({ type: 'Text', text: /░/ })).toBeUndefined()
    await narrow.unmount()
  })

  test('the sprite and the exhaust move on the clock', async ($, on) => {
    const clock = mock.clock(on)
    const blits: { requestId: string; key: string; cells: string }[] = []
    on('ui.blit', ($, e) => {
      if ('cells' in e) blits.push({ requestId: e.requestId, key: e.key, cells: e.cells })

      return { value: {} }
    })
    const fill = cosmos(on)
    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    fill.tokens = 185_000
    await $.turn.complete({ ...TURN, turnId: 't1' })

    const ui = await $.ui.mount({ ...band(120), surface: 'terminal', requestId: 'band' })
    expect(await ui.find({ type: 'Text', text: 'Black Hole' })).toBeDefined()
    await clock.advance(1000)

    const sprites = blits.filter(blit => blit.key === 'sprite')
    expect(sprites.length).toBeGreaterThan(5)
    expect(sprites.every(blit => blit.requestId === 'band')).toBe(true)
    expect(new Set(sprites.map(blit => blit.cells)).size).toBeGreaterThan(1)
    expect(blits.some(blit => blit.key === 'flame')).toBe(true)
    await ui.unmount()
  })
})

describe('token-space sprites', () => {
  test('every body is a full grid of single-width cells, and it moves', () => {
    for (const body of BODIES) {
      const frames = Array.from({ length: 24 }, (_, t) => spriteCells(body, t))
      for (const cells of frames) {
        const points = glyphs(cells)
        expect(points.length).toBe(SPRITE_COLUMNS * SPRITE_ROWS)
        expect(points.every(p => p === 0x20 || (p >= 0x2580 && p <= 0x2593) || (p >= 0x2800 && p <= 0x28ff))).toBe(true)
      }
      expect(new Set(frames).size).toBeGreaterThan(1)
    }
  })

  test('the exhaust points behind the nose for thrust and ahead of it for a retro-burn', () => {
    expect(glyphs(flameCells(false, 3))[3]).toBe(0x25b6)
    expect(glyphs(flameCells(true, 3))[0]).toBe(0x25b6)
  })
})

describe('token-space on the desktop', () => {
  test('the one-line band keeps the zone, the fill and the thrust', async ($, on) => {
    const fill = cosmos(on)
    fill.tokens = 20_000
    await $.turn.complete({ ...TURN, turnId: 't1' })
    fill.tokens = 118_300
    await $.turn.complete({ ...TURN, turnId: 't2' })

    const ui = await $.ui.mount({ ...band(120), surface: 'desktop' })
    expect(await ui.find({ type: 'Text', text: '🧊 Ice Giants' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '59%' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '▁▅' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '🚀 +98.3k thrust' })).toBeDefined()
    await ui.unmount()
  })

  test('the chart keeps the last 12 turns, and a narrow line sheds region and chart', async ($, on) => {
    const fill = cosmos(on)
    for (let turn = 1; turn <= 15; turn += 1) {
      fill.tokens = turn * 10_000
      await $.turn.complete({ ...TURN, turnId: `t${turn}` })
    }

    const wide = await $.ui.mount({ ...band(120), surface: 'desktop' })
    expect(await wide.find({ type: 'Text', text: '▂▃▃▃▄▄▅▅▅▆▆▇' })).toBeDefined()
    await wide.unmount()

    const narrow = await $.ui.mount({ ...band(60), surface: 'desktop' })
    expect(await narrow.find({ type: 'Text', text: '☄️ Kuiper Belt' })).toBeDefined()
    expect(await narrow.find({ type: 'Text', text: 'Deep Space' })).toBeUndefined()
    expect(await narrow.find({ type: 'Text', text: /▆/ })).toBeUndefined()
    await narrow.unmount()
  })
})

describe('token-space on every surface', () => {
  test('past 90% the band is a black hole', async ($, on) => {
    const fill = cosmos(on)
    fill.tokens = 185_000
    await $.turn.complete({ ...TURN, turnId: 't1' })

    for (const surface of ['terminal', 'desktop'] as const) {
      const ui = await $.ui.mount({ ...band(120), surface })
      expect(await ui.find({ type: 'Text', text: 'Black Hole' })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: 'Event Horizon' })).toBeDefined()
      expect(await ui.find({ type: 'Text', text: '93%' })).toBeDefined()
      await ui.unmount()
    }
  })

  test('before the first response, and after /clear, it waits for telemetry', async ($, on) => {
    const fill = cosmos(on)
    for (const surface of ['terminal', 'desktop'] as const) {
      const before = await $.ui.mount({ ...band(120), surface })
      expect(await before.find({ type: 'Text', text: 'awaiting first burn' })).toBeDefined()
      await before.unmount()
    }

    fill.tokens = 50_000
    await $.turn.complete({ ...TURN, turnId: 't1' })
    await $.session.end({ reason: 'clear', sessionId: 's1', resume: { id: 's1' } })

    const after = await $.ui.mount({ ...band(120), surface: 'terminal' })
    expect(await after.find({ type: 'Text', text: 'awaiting first burn' })).toBeDefined()
    await after.unmount()
  })
})

describe('token-space spinner', () => {
  test('while a turn runs the spinner is a rocket, the word of the moment, the clock and the fill', async ($, on) => {
    const clock = mock.clock(on)
    const fill = cosmos(on)
    fill.tokens = 118_300
    await $.turn.start({ text: 'oi', turnId: 't1' })
    await clock.advance(12_400)

    const ui = await $.ui.mount({ ...spinner('thinking'), surface: 'terminal' })
    expect(await ui.find({ type: 'Raster', key: 'ship' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Orbitando…  0:12 · 59% do contexto' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /Sauteing/ })).toBeUndefined()
    await ui.unmount()

    const busy = await $.ui.mount({ ...spinner('tool-use', 'Compacting conversation'), surface: 'terminal' })
    expect(await busy.find({ type: 'Text', text: 'Compacting conversation' })).toBeDefined()
    await busy.unmount()
  })

  test('the rocket moves on the clock, and the desktop keeps its own row', async ($, on) => {
    const clock = mock.clock(on)
    const blits: { requestId: string; key: string; cells: string }[] = []
    on('ui.blit', ($, e) => {
      if ('cells' in e) blits.push({ requestId: e.requestId, key: e.key, cells: e.cells })

      return { value: {} }
    })
    on('ui.render', { component: 'Spinner' }, ($, e) => {
      const { Text } = $.ui.resolve(e)

      return <Text>engine spinner</Text>
    })
    cosmos(on)
    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await $.turn.start({ text: 'oi', turnId: 't1' })

    const ui = await $.ui.mount({ ...spinner('thinking'), surface: 'terminal', requestId: 'main' })
    await clock.advance(1000)
    const ships = blits.filter(blit => blit.key === 'ship')
    expect(ships.length).toBeGreaterThan(5)
    expect(ships.every(blit => blit.requestId === 'main')).toBe(true)
    expect(new Set(ships.map(blit => blit.cells)).size).toBeGreaterThan(1)
    await ui.unmount()

    const desktop = await $.ui.mount({ ...spinner('thinking'), surface: 'desktop' })
    expect(await desktop.find({ type: 'Text', text: 'engine spinner' })).toBeDefined()
    await desktop.unmount()
  })

  test('the scene is one row of single-width cells with the nose in the hull color', () => {
    for (let t = 0; t < 40; t += 1) {
      const points = glyphs(shipCells(t, 0x2f6bff))
      expect(points.length).toBe(SHIP_COLUMNS)
      expect(points.filter(p => p === 0x25b6).length).toBe(1)
      expect(points.every(p => [0x20, 0x2500, 0x2591, 0x2592, 0x2593, 0x25b6].includes(p) || (p >= 0x2800 && p <= 0x28ff))).toBe(true)
    }
  })
})


describe('token-space effort and the right column', () => {
  test('a wide band puts effort, telemetry and thrust in a column at the right edge', async ($, on) => {
    const fill = cosmos(on)
    on('settings.read', () => ({ value: { effortLevel: 'high' } }))
    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    fill.tokens = 20_000
    await $.turn.complete({ ...TURN, turnId: 't1' })

    const wide = await $.ui.mount({ ...band(120), surface: 'terminal' })
    expect(await wide.find({ type: 'Raster', key: 'effort' })).toBeDefined()
    expect(await wide.find({ type: 'Box', text: 'effort  high' })).toBeDefined()
    const boxes = await wide.findAll({ type: 'Box', text: /effort/ })
    const right = boxes.find(box => box.props.alignItems === 'flex-end')
    expect(right?.text).toMatch(/^effort.*telemetry.*thrust$/s)
    expect(right?.text).not.toMatch(/Inner Planets|Solar Core/)
    await wide.unmount()

    const narrow = await $.ui.mount({ ...band(70), surface: 'terminal' })
    expect(await narrow.find({ type: 'Raster', key: 'effort' })).toBeDefined()
    const stacked = await narrow.findAll({ type: 'Box' })
    expect(stacked.some(box => box.props.alignItems === 'flex-end')).toBe(false)
    await narrow.unmount()
  })
})

describe('token-space effort stars', () => {
  test('stars light up to the level, and at max they never hold still', () => {
    const high = glyphs(effortCells(2, 0))
    expect(high).toEqual([0x2605, 0x2605, 0x2605, 0x2606, 0x2606])
    const frames = Array.from({ length: 16 }, (_, t) => effortCells(4, t))
    expect(new Set(frames).size).toBeGreaterThan(8)
    expect(frames.some(cells => glyphs(cells).includes(0x2726))).toBe(true)
  })
})
