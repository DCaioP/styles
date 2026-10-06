/** One reading of the context window, taken when a main-loop turn ends. */
export type Sample = { tokens: number; window: number }

declare module 'claude-code' {
  interface PluginState {
    'token-space': { samples: Sample[]; isBlinkOn: boolean; effort: string | null }
  }
}
