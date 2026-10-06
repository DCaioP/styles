import { atom, read, update } from 'claude-code'
import type { Register, RenderElement } from 'claude-code'

import type { Sample } from '../types'
import type { Body } from './cosmos'
import {
  HISTORY,
  barOf,
  deltaOf,
  formatDelta,
  formatElapsed,
  formatTokens,
  percentOf,
  spinnerWord,
  zoneOf,
} from './cosmos'
import {
  EFFORT_COLUMNS,
  FLAME_COLUMNS,
  SHIP_COLUMNS,
  SPRITE_COLUMNS,
  SPRITE_ROWS,
  effortCells,
  flameCells,
  shipCells,
  spriteCells,
} from './sprites'

const samples = atom({ plugin: 'token-space', key: 'samples' } as const, [])
const isBlinkOn = atom({ plugin: 'token-space', key: 'isBlinkOn' } as const, false)
/** The reasoning effort the main loop's last request went with: the saved setting until one is sent. */
const effort = atom({ plugin: 'token-space', key: 'effort' } as const, null)
const EFFORT_LEVELS = ['low', 'medium', 'high', 'xhigh', 'max'] as const
const EFFORT_COLOR = '#C792EA'

const SEPARATOR = ' │ '
/** About eight frames a second; the black hole's glow flips every fifth, the spinner's clock every eighth. */
const FRAME_MS = 125
const BLINK_FRAMES = 5
const SECOND_FRAMES = 8
/** The cosmic map strip beside the percentage: 16 cells, 24 when the band splits in two columns. */
const GAUGE_CELLS = 16
const WIDE_GAUGE_CELLS = 24
/** From this width the telemetry moves to a column of its own at the right edge. */
const COLUMNS_FOR_SPLIT = 80

/** Below these widths the one-line band sheds the region's name, then the chart. */
const COLUMNS_FOR_REGION = 92
const COLUMNS_FOR_CHART = 74
/** Below this width the terminal band sheds the map strip. */
const COLUMNS_FOR_GAUGE = 60

export const register: Register = on => {
  // What the animation repaints, as the last drawing left it; a reload draws again.
  let frame = 0
  let bandId: string | undefined
  let body: Body = 'sun'
  let flame: 'thrust' | 'retro' | null = null
  let effortRank = -1
  let isPainting = false
  // The spinners drawn as a rocket, by requestId; one leaves when its blit is refused.
  const spinners = new Set<string>()
  let hull = 0xe8e8f0
  let turnStartedAt: number | undefined

  on('session.start', async ($, e, next) => {
    // A resumed session may already have a reading: start the chart from it.
    const { context } = await $.session.usage()
    if (context.tokens !== undefined) {
      const sample: Sample = { tokens: context.tokens, window: context.window }
      await update($, samples, list => (list.length === 0 ? [sample] : list))
    }

    // A settings read that fails only leaves the effort unknown until the first request says it.
    const saved = (await $.settings.read().catch(() => ({}) as Record<string, unknown>)).effortLevel
    if (typeof saved === 'string') await update($, effort, now => now ?? saved)

    $.clock.every(FRAME_MS, () => {
      if (isPainting) return
      isPainting = true
      void (async () => {
        frame += 1

        // The event horizon flashes: while the latest reading is a black hole the
        // glow flips, and it is put out once the fill drops below it.
        if (frame % BLINK_FRAMES === 0) {
          const last = (await read($, samples)).at(-1)
          const isCritical = last !== undefined && zoneOf(percentOf(last)).isCritical
          if (isCritical || (await read($, isBlinkOn))) {
            await update($, isBlinkOn, isOn => isCritical && !isOn)
          }
        }

        // A band that is collapsed or not drawn refuses the blit; the next frame tries again.
        if (bandId !== undefined) {
          await $.ui.blit({ requestId: bandId, key: 'sprite', cells: spriteCells(body, frame) })
          if (flame !== null) {
            await $.ui.blit({ requestId: bandId, key: 'flame', cells: flameCells(flame === 'retro', frame) })
          }
          if (effortRank >= 0) {
            await $.ui.blit({ requestId: bandId, key: 'effort', cells: effortCells(effortRank, frame) })
          }
        }

        for (const requestId of spinners) {
          const shown = await $.ui.blit({ requestId, key: 'ship', cells: shipCells(frame, hull) })
          if (shown.deny !== undefined) spinners.delete(requestId)
        }
        // The turn's clock is text: once a second the drawings are asked again.
        if (turnStartedAt !== undefined && frame % SECOND_FRAMES === 0) $.ui.invalidate('ui.render')
      })().finally(() => {
        isPainting = false
      })
    })

    return next(e)
  })

  // Each request of the main loop says which effort it went with, after any downgrade for the model.
  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined && e.effort !== undefined) {
      const sent = String(e.effort)
      await update($, effort, () => sent)
    }

    return yield* next(e)
  })

  on('turn.start', async ($, e, next) => {
    turnStartedAt = await $.clock.now()

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) return result

    turnStartedAt = undefined

    const { context } = await $.session.usage()
    if (context.tokens === undefined) return result

    const sample: Sample = { tokens: context.tokens, window: context.window }
    await update($, samples, list => [...list, sample].slice(-HISTORY))

    return result
  })

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') await update($, samples, () => [])

    return next(e)
  })

  // While a turn runs, the line that animates is a rocket crossing the stars.
  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    if (e.surface !== 'terminal') return next(e)

    const { Box, Raster, Text } = $.ui.resolve(e)
    const now = await $.clock.now()
    turnStartedAt ??= now
    const { context } = await $.session.usage()
    const percent = context.tokens === undefined ? undefined : percentOf({ tokens: context.tokens, window: context.window })
    const zone = zoneOf(percent ?? 0)
    spinners.add(e.requestId)
    hull = Number.parseInt(zone.color.slice(1), 16)

    return (
      <Box flexDirection="row">
        <Raster key="ship" columns={SHIP_COLUMNS} rows={1} cells={shipCells(frame, hull)} />
        <Text wrap="truncate-end">
          {' '}
          <Text color={zone.color} bold>{e.props.message ?? spinnerWord(e.props.mode)}</Text>
          <Text dimColor>{e.props.suffix}  {formatElapsed(now - turnStartedAt)}</Text>
          {percent !== undefined && [<Text dimColor> · </Text>, <Text color={zone.color}>{percent}% do contexto</Text>]}
        </Text>
      </Box>
    )
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)

    const list = await read($, samples)
    const last = list.at(-1)
    const window = last?.window ?? (await $.session.usage()).context.window
    const percent = last === undefined ? 0 : percentOf(last)
    const zone = zoneOf(percent)
    const isGlowing = zone.isCritical && (await read($, isBlinkOn))
    const columns = e.props.bodyColumns
    const delta = deltaOf(list)

    if (e.surface === 'terminal') {
      const { Box, Raster, Text } = $.ui.resolve(e)
      bandId = e.requestId
      body = zone.body
      flame = last === undefined ? null : delta < 0 ? 'retro' : 'thrust'

      const isSplit = columns >= COLUMNS_FOR_SPLIT
      const cells = isSplit ? WIDE_GAUGE_CELLS : GAUGE_CELLS
      const gauge: RenderElement[] = []
      for (let cell = 0; cell < cells; cell += 1) {
        const reach = ((cell + 0.5) * 100) / cells
        const isFilled = reach <= percent
        gauge.push(
          <Text color={zoneOf(reach).color} dimColor={!isFilled}>{isFilled ? '█' : '░'}</Text>,
        )
      }
      const chart: RenderElement[] =
        last === undefined
          ? [<Text dimColor>awaiting first burn</Text>]
          : list.map(sample => {
              const reading = percentOf(sample)

              return <Text color={zoneOf(reading).color}>{barOf(reading)}</Text>
            })

      const level = await read($, effort)
      effortRank = EFFORT_LEVELS.indexOf(level as (typeof EFFORT_LEVELS)[number])
      const isMaxEffort = effortRank === EFFORT_LEVELS.length - 1
      const effortLine = (
        <Box flexDirection="row">
          <Text dimColor>effort </Text>
          {effortRank >= 0 && (
            <Raster key="effort" columns={EFFORT_COLUMNS} rows={1} cells={effortCells(effortRank, frame)} />
          )}
          <Text wrap="truncate-end">
            {' '}
            <Text color={EFFORT_COLOR} bold inverse={isMaxEffort}>{isMaxEffort ? ' max ' : (level ?? '—')}</Text>
          </Text>
        </Box>
      )
      const zoneLine = (
        <Text wrap="truncate-end">
          <Text color={zone.color} bold inverse={isGlowing}>{zone.name}</Text>
          {zone.region !== '' && <Text color={zone.accent}>  {zone.region}</Text>}
        </Text>
      )
      const percentLine = (
        <Text wrap="truncate-end">
          <Text color={zone.color} bold inverse={isGlowing}>{percent}%</Text>
          {columns >= COLUMNS_FOR_GAUGE && [<Text> </Text>, ...gauge]}
        </Text>
      )
      const tokensLine = (
        <Text wrap="truncate-end">
          <Text bold>{last === undefined ? '—' : formatTokens(last.tokens)}</Text>
          <Text dimColor> / {formatTokens(window)}</Text>
        </Text>
      )
      const chartLine = (
        <Text wrap="truncate-end">
          <Text dimColor>telemetry </Text>
          {chart}
        </Text>
      )
      const thrustLine = last !== undefined && (
        <Box flexDirection="row">
          <Raster key="flame" columns={FLAME_COLUMNS} rows={1} cells={flameCells(delta < 0, frame)} />
          <Text wrap="truncate-end">
            {' '}
            <Text bold>{delta < 0 ? '−' : '+'}{formatTokens(Math.abs(delta))}</Text>
            <Text dimColor> {delta < 0 ? 'retro-burn' : 'thrust'}</Text>
          </Text>
        </Box>
      )
      const sprite = <Raster key="sprite" columns={SPRITE_COLUMNS} rows={SPRITE_ROWS} cells={spriteCells(zone.body, frame)} />

      if (isSplit) {
        return (
          <Box flexDirection="row" justifyContent="space-between">
            <Box flexDirection="row" flexShrink={1}>
              {sprite}
              <Box flexDirection="column" marginLeft={2} flexShrink={1}>
                {zoneLine}
                {percentLine}
                {tokensLine}
              </Box>
            </Box>
            <Box flexDirection="column" alignItems="flex-end" marginLeft={2}>
              {effortLine}
              {chartLine}
              {thrustLine}
            </Box>
          </Box>
        )
      }

      return (
        <Box flexDirection="row">
          {sprite}
          <Box flexDirection="column" marginLeft={2} flexShrink={1}>
            {zoneLine}
            <Text wrap="truncate-end">
              {percentLine}
              <Text>  </Text>
              {tokensLine}
            </Text>
            {chartLine}
            {thrustLine}
            {effortLine}
          </Box>
        </Box>
      )
    }

    // Surfaces with no cell grid (the desktop) keep the one-line band.
    const { Text } = $.ui.resolve(e)
    const parts: RenderElement[] = []

    if (last === undefined) {
      parts.push(
        <Text color={zone.color} bold>{zone.icon} {zone.name}</Text>,
        <Text dimColor>{SEPARATOR}0%{SEPARATOR}— / {formatTokens(window)}{SEPARATOR}awaiting first burn</Text>,
      )

      return <Text wrap="truncate-end">{parts}</Text>
    }

    parts.push(<Text color={zone.color} bold inverse={isGlowing}>{zone.icon} {zone.name}</Text>)
    if (zone.region !== '' && columns >= COLUMNS_FOR_REGION) {
      parts.push(<Text color={zone.accent}> · {zone.region}</Text>)
    }
    parts.push(
      <Text dimColor>{SEPARATOR}</Text>,
      <Text color={zone.color} bold inverse={isGlowing}>{percent}%</Text>,
      <Text dimColor>{SEPARATOR}</Text>,
      <Text bold>{formatTokens(last.tokens)}</Text>,
      <Text dimColor> / {formatTokens(last.window)}</Text>,
    )
    if (columns >= COLUMNS_FOR_CHART) {
      parts.push(<Text dimColor>{SEPARATOR}</Text>)
      for (const sample of list) {
        const reading = percentOf(sample)
        parts.push(<Text color={zoneOf(reading).color}>{barOf(reading)}</Text>)
      }
    }
    parts.push(<Text dimColor>{SEPARATOR}</Text>, <Text>{formatDelta(delta)}</Text>)

    return <Text wrap="truncate-end">{parts}</Text>
  })
}
