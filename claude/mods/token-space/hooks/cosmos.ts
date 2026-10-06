import type { Sample } from '../types'

/** How many turns the telemetry chart keeps. */
export const HISTORY = 12

/** Which animated sprite draws a zone on the terminal. */
export type Body = 'sun' | 'rocky' | 'gas' | 'ice' | 'comet' | 'hole'

/** A region of the map: where a given fill of the context window sits. */
export type Zone = {
  body: Body
  icon: string
  name: string
  region: string
  color: string
  accent: string
  isCritical: boolean
}

/** The map from the Sun outward; each zone holds the fills below `below`. */
const ZONES: readonly (Zone & { below: number })[] = [
  { below: 15, body: 'sun', icon: '☀️', name: 'Solar Core', region: '', color: '#FFE600', accent: '#FFE600', isCritical: false },
  { below: 30, body: 'rocky', icon: '🪨', name: 'Inner Planets', region: 'Mercury-Mars', color: '#FF8C00', accent: '#FFB347', isCritical: false },
  { below: 50, body: 'gas', icon: '🪐', name: 'Gas Giants', region: 'Jupiter-Saturn', color: '#FFBF00', accent: '#00E5FF', isCritical: false },
  { below: 70, body: 'ice', icon: '🧊', name: 'Ice Giants', region: 'Uranus-Neptune', color: '#2F6BFF', accent: '#6E9BFF', isCritical: false },
  { below: 90, body: 'comet', icon: '☄️', name: 'Kuiper Belt', region: 'Deep Space', color: '#FF00FF', accent: '#FF7AFF', isCritical: false },
  { below: Infinity, body: 'hole', icon: '🕳️', name: 'Black Hole', region: 'Event Horizon', color: '#FF1E1E', accent: '#FF1E1E', isCritical: true },
]

const BARS = '▁▂▃▄▅▆▇█'

/** The fill of the window as a whole percentage, the figure the zone is chosen by. */
export function percentOf(sample: Sample): number {
  return sample.window > 0 ? Math.round((sample.tokens / sample.window) * 100) : 0
}

export function zoneOf(percent: number): Zone {
  return ZONES.find(zone => percent < zone.below) ?? ZONES[ZONES.length - 1]!
}

/** One bar of the chart: the fill on an absolute 0–100% scale, eight steps. */
export function barOf(percent: number): string {
  return BARS[Math.max(0, Math.min(7, Math.floor(percent / 12.5)))]!
}

/** 950 → "950", 98_300 → "98.3k", 200_000 → "200k", 1_000_000 → "1M". */
export function formatTokens(tokens: number): string {
  const thousands = Math.round(tokens / 100) / 10
  if (thousands >= 1000) return `${trim(tokens / 1_000_000)}M`
  if (tokens >= 1000) return `${trim(thousands)}k`

  return String(tokens)
}

function trim(value: number): string {
  return value.toFixed(1).replace(/\.0$/, '')
}

/** What the last turn added: thrust when the window grew, a retro-burn when a compaction shrank it. */
export function formatDelta(delta: number): string {
  return delta >= 0
    ? `🚀 +${formatTokens(delta)} thrust`
    : `🪂 −${formatTokens(-delta)} retro-burn`
}

/** The last turn's change: the latest reading against the one before it, or against zero on the first. */
export function deltaOf(samples: readonly Sample[]): number {
  const last = samples.at(-1)
  const before = samples.at(-2)

  return (last?.tokens ?? 0) - (before?.tokens ?? 0)
}

/** What the turn is doing, as the spinner's mode names it (the engine's word stands for it). */
export type SpinnerMode = 'requesting' | 'responding' | 'thinking' | 'tool-input' | 'tool-use'

const SPINNER_WORDS: Record<SpinnerMode, string> = {
  requesting: 'Contatando a base',
  thinking: 'Orbitando',
  responding: 'Transmitindo',
  'tool-input': 'Manobrando',
  'tool-use': 'Manobrando',
}

export function spinnerWord(mode: SpinnerMode): string {
  return SPINNER_WORDS[mode]
}

/** 12_400 → "0:12", 64_000 → "1:04". */
export function formatElapsed(ms: number): string {
  const seconds = Math.max(0, Math.floor(ms / 1000))

  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
}
