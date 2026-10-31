import { ref } from 'vue'

export interface Preset { id: string; name: string; css: string }

/** CSS versions of BackgroundPreset.all in Sources/Avora/Backgrounds.swift. */
export const presets: Preset[] = [
  { id: 'avora', name: 'Avora', css: 'linear-gradient(to bottom right, #F26B1D, #FFD3A1)' },
  { id: 'ember', name: 'Ember', css: 'linear-gradient(to bottom right, #2A1A12, #F26B1D)' },
  { id: 'grove', name: 'Grove', css: 'linear-gradient(to bottom right, #2F6B3A, #121318)' },
  { id: 'studio', name: 'Studio', css: 'radial-gradient(circle at 50% 30%, #2C2C33 0%, #15151A 60%)' },
  { id: 'sand', name: 'Sand', css: 'radial-gradient(circle at 50% 30%, #6B5A45 0%, #2A2218 60%)' },
  {
    id: 'aurora',
    name: 'Aurora',
    css: 'radial-gradient(circle at 25% 25%, #4A3370 0%, transparent 34%), radial-gradient(circle at 75% 70%, #2A4D7A 0%, transparent 39%), radial-gradient(circle at 50% 50%, #1A3A3A 0%, transparent 37%), #0A0A0E',
  },
  { id: 'iris', name: 'Iris', css: 'linear-gradient(to bottom right, #667EEA, #764BA2)' },
  { id: 'blossom', name: 'Blossom', css: 'linear-gradient(to bottom right, #F093FB, #F5576C)' },
  { id: 'sky', name: 'Sky', css: 'linear-gradient(to bottom right, #4FACFE, #00F2FE)' },
  { id: 'mint', name: 'Mint', css: 'linear-gradient(to bottom right, #43E97B, #38F9D7)' },
  { id: 'sunset', name: 'Sunset', css: 'linear-gradient(to bottom right, #FF8A00, #E52E71)' },
  { id: 'indigo', name: 'Indigo', css: 'linear-gradient(to bottom right, #0EA5E9, #7C3AED)' },
]

/** Shared by every stage, the swatches and the menu bar demo, like the app's one preference. */
export const selectedBackground = ref('avora')

export const presetCSS = (id: string) => (presets.find(p => p.id === id) ?? presets[0]).css
