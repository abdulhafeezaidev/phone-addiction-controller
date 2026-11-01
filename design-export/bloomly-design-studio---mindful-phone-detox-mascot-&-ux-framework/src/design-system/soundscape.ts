import { MascotMood } from './mascot-engine';

export interface SoundscapeToken {
  id: string;
  name: string;
  category: 'Celebration Chime' | 'Organic Wood' | 'Resonant Drone' | 'Nature Droplet' | 'Silver Cascade';
  recommendedFor: MascotMood[];
  triggerDescription: string;
  musicalKey: string;
  baseFrequencies: number[];
  waveform: 'sine' | 'triangle' | 'sine_layered' | 'bell_fm';
  adsr: {
    attack: string;
    decay: string;
    sustain: string;
    release: string;
  };
  durationMs: number;
  psychoacousticGoal: string;
  agentImplementationSpec: string;
}

export const SOUNDSCAPE_TOKENS: SoundscapeToken[] = [
  {
    id: 'bell_528_harmony',
    name: 'Golden Solfeggio Bell (528 Hz)',
    category: 'Celebration Chime',
    recommendedFor: ['celebrating'],
    triggerDescription: 'Triggered when the mascot celebrates a completed daily quota or major detox milestone.',
    musicalKey: '528 Hz (C5 Solfeggio / "Transformation Frequency")',
    baseFrequencies: [528, 1056, 1584],
    waveform: 'bell_fm',
    adsr: {
      attack: '15ms (gentle strike)',
      decay: '850ms',
      sustain: '30% volume',
      release: '1200ms exponential tail',
    },
    durationMs: 2200,
    psychoacousticGoal:
      'Stimulates parasympathetic nervous settling. Unlike casino-like slot machine alerts, this shimmering bell resonates like a temple chime, rewarding patience rather than frantic taps.',
    agentImplementationSpec:
      'In React Native / Flutter, play bundled "snd_lumi_celebrate_528hz.wav" (48kHz, 24-bit PCM, volume peak -3dB) accompanied by Double Heartbeat Haptic.',
  },
  {
    id: 'kalimba_pentatonic_sparkle',
    name: 'Bamboo Kalimba Arpeggio',
    category: 'Organic Wood',
    recommendedFor: ['celebrating', 'watering_plant'],
    triggerDescription: 'Triggered when the user checks off an individual mindful task (e.g. 15-minute phone-free walk).',
    musicalKey: 'C Major Pentatonic (C5, E5, G5, A5)',
    baseFrequencies: [523.25, 659.25, 783.99, 880.0],
    waveform: 'triangle',
    adsr: {
      attack: '5ms (fast tactile pluck)',
      decay: '450ms per tine',
      sustain: '10%',
      release: '600ms soft damping',
    },
    durationMs: 1400,
    psychoacousticGoal:
      'Wooden organic timbre grounds the user in the physical tactile world, counteracting the cold synthetic feel of algorithmic screen notifications.',
    agentImplementationSpec:
      'Play "snd_lumi_kalimba_sparkle.wav" sequentially arpeggiated at 70ms intervals across 4 tines with gentle stereo panning.',
  },
  {
    id: 'singing_bowl_drone',
    name: 'Tibetan Singing Bowl Hum (216 Hz)',
    category: 'Resonant Drone',
    recommendedFor: ['sleeping', 'zen_focus', 'comforting'],
    triggerDescription: 'Triggered when entering night curfew wind-down, emergency bypass shield, or deep focus session.',
    musicalKey: '216 Hz (Low A3 with 4.5 Hz Alpha/Theta binaural pulse)',
    baseFrequencies: [216, 432, 648],
    waveform: 'sine_layered',
    adsr: {
      attack: '400ms (soothing swell)',
      decay: '1500ms',
      sustain: '50% ambient level',
      release: '2000ms smooth fade',
    },
    durationMs: 3500,
    psychoacousticGoal:
      'Induces alpha-to-theta brainwave transition, lowering cortisol and physical heart rate when the user steps away from screen stimulation at bedtime.',
    agentImplementationSpec:
      'Play "snd_lumi_singing_bowl_hum.wav" with a subtle 4.5Hz low-frequency oscillation filter. Loop seamlessly if active session is ongoing.',
  },
  {
    id: 'dewdrop_water_pluck',
    name: 'Dewdrop Water Pluck',
    category: 'Nature Droplet',
    recommendedFor: ['idle_happy', 'gentle_nudge'],
    triggerDescription: 'Triggered when tapping Lumi to pet them, or completing a 5-second mindful breath.',
    musicalKey: 'Descending Glissando (880 Hz → 660 Hz)',
    baseFrequencies: [880, 660],
    waveform: 'sine',
    adsr: {
      attack: '2ms',
      decay: '180ms',
      sustain: '0%',
      release: '220ms',
    },
    durationMs: 400,
    psychoacousticGoal:
      'A light, playful nature drop that brings warmth and affection without interrupting the user’s real-world environment.',
    agentImplementationSpec:
      'Play "snd_lumi_dewdrop.wav" triggered on UI touch-down with zero latency and light taptic engine feedback.',
  },
  {
    id: 'zen_wind_chime',
    name: 'Misty Forest Wind Chime',
    category: 'Silver Cascade',
    recommendedFor: ['celebrating', 'watering_plant'],
    triggerDescription: 'Triggered when unlocking a new multi-day streak or garden bloom evolution tier.',
    musicalKey: 'Pentatonic Sparkle (E5, G#5, B5, E6)',
    baseFrequencies: [659.25, 830.61, 987.77, 1318.51],
    waveform: 'bell_fm',
    adsr: {
      attack: '10ms',
      decay: '700ms',
      sustain: '20%',
      release: '1500ms airy shimmer',
    },
    durationMs: 2400,
    psychoacousticGoal:
      'Creates a sense of wonder and organic accomplishment, linking streak maintenance to blossoming nature rather than competitive pressure.',
    agentImplementationSpec:
      'Play "snd_lumi_wind_chime_cascade.wav" concurrently with particle confetti emission.',
  },
];

/**
 * Returns the recommended soundscape token for a given mascot state
 */
export function getRecommendedSoundscapeForMood(mood: MascotMood): SoundscapeToken {
  const match = SOUNDSCAPE_TOKENS.find((token) => token.recommendedFor.includes(mood));
  return match || SOUNDSCAPE_TOKENS[0];
}
