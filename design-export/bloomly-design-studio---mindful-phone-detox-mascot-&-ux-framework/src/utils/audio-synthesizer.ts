import { SoundscapeToken } from '../design-system/soundscape';

let audioCtx: AudioContext | null = null;
export type AmbientSoundscape = 'forest_rain' | 'gentle_stream' | 'soft_drone';

function getAudioContext(): AudioContext {
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    audioCtx = new AudioContextClass();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
}

/**
 * Procedural Web Audio Synthesizer for Mindful Soundscape Tokens.
 * Creates organic, calming auditory feedback without external audio files.
 */
export function playSoundscapeToken(token: SoundscapeToken): void {
  try {
    const ctx = getAudioContext();
    const now = ctx.currentTime;

    if (token.id === 'bell_528_harmony') {
      // 528 Hz Solfeggio Golden Bell with Octave Harmonics
      const masterGain = ctx.createGain();
      masterGain.gain.setValueAtTime(0, now);
      masterGain.gain.linearRampToValueAtTime(0.35, now + 0.02);
      masterGain.gain.exponentialRampToValueAtTime(0.0001, now + 2.2);
      masterGain.connect(ctx.destination);

      [528, 1056, 1584, 2112].forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        const amplitude = 1 / Math.pow(idx + 1, 1.4);

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now);

        gain.gain.setValueAtTime(amplitude, now);
        osc.connect(gain);
        gain.connect(masterGain);

        osc.start(now);
        osc.stop(now + 2.2);
      });
      return;
    }

    if (token.id === 'kalimba_pentatonic_sparkle') {
      // Bamboo Kalimba 4-Note Arpeggio
      const notes = [523.25, 659.25, 783.99, 880.0]; // C5, E5, G5, A5
      notes.forEach((freq, idx) => {
        const noteTime = now + idx * 0.09;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        const filter = ctx.createBiquadFilter();

        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(1800, noteTime);

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, noteTime);

        gain.gain.setValueAtTime(0, noteTime);
        gain.gain.linearRampToValueAtTime(0.25, noteTime + 0.005);
        gain.gain.exponentialRampToValueAtTime(0.0001, noteTime + 0.6);

        osc.connect(filter);
        filter.connect(gain);
        gain.connect(ctx.destination);

        osc.start(noteTime);
        osc.stop(noteTime + 0.65);
      });
      return;
    }

    if (token.id === 'singing_bowl_drone') {
      // Tibetan Singing Bowl 216 Hz with subtle 4.5Hz Theta pulse
      const masterGain = ctx.createGain();
      masterGain.gain.setValueAtTime(0, now);
      masterGain.gain.linearRampToValueAtTime(0.28, now + 0.5);
      masterGain.gain.exponentialRampToValueAtTime(0.0001, now + 3.4);
      masterGain.connect(ctx.destination);

      [216, 432].forEach((freq) => {
        const osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now);

        // Subtle slow vibrato for meditative warmth
        const lfo = ctx.createOscillator();
        const lfoGain = ctx.createGain();
        lfo.frequency.setValueAtTime(4.5, now);
        lfoGain.gain.setValueAtTime(1.5, now);
        lfo.connect(osc.frequency);
        lfo.start(now);
        lfo.stop(now + 3.5);

        osc.connect(masterGain);
        osc.start(now);
        osc.stop(now + 3.5);
      });
      return;
    }

    if (token.id === 'dewdrop_water_pluck') {
      // Natural Water Droplet with downward pitch glide
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, now);
      osc.frequency.exponentialRampToValueAtTime(620, now + 0.18);

      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.3, now + 0.004);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.38);
      return;
    }

    if (token.id === 'zen_wind_chime') {
      // Misty Forest Wind Chime cascade
      const chimeFreqs = [659.25, 830.61, 987.77, 1318.51];
      chimeFreqs.forEach((freq, idx) => {
        const chimeTime = now + idx * 0.12;
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, chimeTime);

        gain.gain.setValueAtTime(0, chimeTime);
        gain.gain.linearRampToValueAtTime(0.2, chimeTime + 0.01);
        gain.gain.exponentialRampToValueAtTime(0.0001, chimeTime + 1.2);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(chimeTime);
        osc.stop(chimeTime + 1.3);
      });
      return;
    }

    // Default fallback chime
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(528, now);
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.8);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.85);
  } catch {
    // Graceful fallback if Web Audio is blocked by browser autoplay policy
  }
}

export function startAmbientSoundscape(scene: AmbientSoundscape): () => void {
  const ctx = getAudioContext();
  const now = ctx.currentTime;
  const nodes: AudioScheduledSourceNode[] = [];
  const disconnectables: AudioNode[] = [];
  const master = ctx.createGain();
  master.gain.setValueAtTime(0, now);
  master.gain.linearRampToValueAtTime(0.075, now + 0.8);
  master.connect(ctx.destination);
  disconnectables.push(master);

  if (scene === 'soft_drone') {
    [108, 162].forEach((frequency, index) => {
      const oscillator = ctx.createOscillator();
      const voiceGain = ctx.createGain();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(frequency, now);
      voiceGain.gain.setValueAtTime(index === 0 ? 0.65 : 0.22, now);
      oscillator.connect(voiceGain);
      voiceGain.connect(master);
      oscillator.start(now);
      nodes.push(oscillator);
      disconnectables.push(oscillator, voiceGain);
    });
  } else {
    const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const channel = noiseBuffer.getChannelData(0);
    let filtered = 0;
    for (let index = 0; index < channel.length; index += 1) {
      const whiteNoise = Math.random() * 2 - 1;
      filtered = scene === 'forest_rain'
        ? filtered * 0.94 + whiteNoise * 0.06
        : filtered * 0.82 + whiteNoise * 0.18;
      channel[index] = filtered;
    }

    const source = ctx.createBufferSource();
    const filter = ctx.createBiquadFilter();
    source.buffer = noiseBuffer;
    source.loop = true;
    filter.type = scene === 'forest_rain' ? 'lowpass' : 'bandpass';
    filter.frequency.setValueAtTime(scene === 'forest_rain' ? 1150 : 720, now);
    filter.Q.setValueAtTime(scene === 'forest_rain' ? 0.4 : 0.7, now);
    source.connect(filter);
    filter.connect(master);
    source.start(now);
    nodes.push(source);
    disconnectables.push(source, filter);
  }

  return () => {
    const stopAt = ctx.currentTime;
    master.gain.cancelScheduledValues(stopAt);
    master.gain.setTargetAtTime(0, stopAt, 0.18);
    window.setTimeout(() => {
      nodes.forEach((node) => {
        try {
          node.stop();
        } catch {
          // A source may already have ended while its fade-out was scheduled.
        }
      });
      disconnectables.forEach((node) => node.disconnect());
    }, 700);
  };
}
