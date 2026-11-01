import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import { MascotCharacter } from './MascotCharacter';
import { MascotMood } from '../design-system/mascot-engine';
import {
  SOUNDSCAPE_TOKENS,
  SoundscapeToken,
  getRecommendedSoundscapeForMood,
} from '../design-system/soundscape';
import { playSoundscapeToken } from '../utils/audio-synthesizer';
import {
  Sparkles,
  Heart,
  Bell,
  CheckCircle2,
  ShieldCheck,
  Moon,
  RefreshCw,
  Volume2,
  VolumeX,
  Copy,
  Check,
  Play,
  Music,
  Waves,
  Headphones,
} from 'lucide-react';

export const InteractiveMascotSimulator: React.FC = () => {
  const [selectedMood, setSelectedMood] = useState<MascotMood>('idle_happy');
  const [copiedText, setCopiedText] = useState(false);
  const [copiedAudioSpec, setCopiedAudioSpec] = useState(false);
  const [autoPlaySound, setAutoPlaySound] = useState(true);
  const [activeSoundToken, setActiveSoundToken] = useState<SoundscapeToken>(
    getRecommendedSoundscapeForMood('idle_happy')
  );
  const [playingTokenId, setPlayingTokenId] = useState<string | null>(null);

  // Trigger celebration confetti
  const triggerConfetti = () => {
    confetti({
      particleCount: 50,
      spread: 60,
      origin: { y: 0.65 },
      colors: ['#4ADE80', '#FDE047', '#F472B6', '#60A5FA', '#DDD6FE'],
    });
  };

  const playAudioForToken = (token: SoundscapeToken) => {
    setPlayingTokenId(token.id);
    playSoundscapeToken(token);
    setTimeout(() => {
      setPlayingTokenId(null);
    }, Math.min(token.durationMs, 2500));
  };

  const handleSelectScenario = (mood: MascotMood) => {
    setSelectedMood(mood);
    const recommended = getRecommendedSoundscapeForMood(mood);
    setActiveSoundToken(recommended);

    if (autoPlaySound) {
      playAudioForToken(recommended);
    }

    if (mood === 'celebrating') {
      triggerConfetti();
    }
  };

  // Preset contextual responses
  const scenarioMap: Record<
    MascotMood,
    {
      label: string;
      icon: React.ReactNode;
      context: string;
      speech: string;
      subtext: string;
      haptic: string;
      aura: string;
    }
  > = {
    idle_happy: {
      label: 'Idle Companion',
      icon: <Sparkles className="w-4 h-4 text-emerald-600" />,
      context: 'Home screen idle state',
      speech: "Hello! I'm Lumi, your pocket guide to calmer tech habits. How can I support you today?",
      subtext: 'Gentle breathing idle loop · Click or tap Lumi to give affection',
      haptic: 'Light Taptic (10ms)',
      aura: '#86EFAC (Sage Green)',
    },
    celebrating: {
      label: 'Task Done / Goal Hit',
      icon: <CheckCircle2 className="w-4 h-4 text-amber-500" />,
      context: 'User finished a 30m screen-free walk or daily quota',
      speech: "You did it! Today's goal is complete! Look at how bright our garden is blooming.",
      subtext: '+20 Sprout Seeds earned · Real life presence celebrated',
      haptic: 'Double Heartbeat Pulse (30ms - 60ms - 40ms)',
      aura: '#FDE047 (Warm Golden Honey)',
    },
    zen_focus: {
      label: 'Zen Focus Mode',
      icon: <RefreshCw className="w-4 h-4 text-emerald-600" />,
      context: 'User started a 25-minute deep work or mindful break',
      speech: 'We are resting our minds together. Breathe in deeply... breathe out slowly.',
      subtext: 'Parasympathetic 4s breathing rhythm · Notifications silenced',
      haptic: 'Calm Wave Pulse (60ms smooth)',
      aura: '#A7F3D0 (Misty Mint)',
    },
    gentle_nudge: {
      label: 'App Open Intercept',
      icon: <Bell className="w-4 h-4 text-orange-500" />,
      context: 'User opened Instagram / TikTok during locked hours',
      speech: 'Hey friend! Checking in with kindness: what are you hoping to find right now?',
      subtext: 'Mindful 5-second friction pause · Zero shame, 100% autonomy',
      haptic: 'Gentle Warning Tick (15ms)',
      aura: '#FDBA74 (Soft Peach Amber - Never Red)',
    },
    comforting: {
      label: 'Emergency Bypass / Off-Track',
      icon: <Heart className="w-4 h-4 text-purple-500" />,
      context: 'User needed phone or slipped past intentional limit',
      speech: 'Life happens, and that is 100% okay! We are learning our rhythm. No guilt here.',
      subtext: "Seedling Shield active · Protects motivation from 'what-the-hell' effect",
      haptic: 'Soft Comfort Pulse (40ms)',
      aura: '#DDD6FE (Lavender Dusk)',
    },
    sleeping: {
      label: 'Night Curfew (Wind Down)',
      icon: <Moon className="w-4 h-4 text-blue-500" />,
      context: 'Bedtime mode active (after 10:00 PM)',
      speech: "Shh... stars are out. It's time to let your eyes rest and recharge your spirit.",
      subtext: 'Nightcap on · Floating gently with soft Zzz particles',
      haptic: 'Fade-out Soothing Wave (120ms)',
      aura: '#93C5FD (Starlight Sky Blue)',
    },
    watering_plant: {
      label: 'Daily Streak Growth',
      icon: <ShieldCheck className="w-4 h-4 text-teal-600" />,
      context: 'Day 5 streak check-in',
      speech: 'Day 5 of intentional living! Ready to water our mindful seedling?',
      subtext: 'Watering can animation · Sprout grows new dewy leaf',
      haptic: 'Double Light Ticks (10ms x 2)',
      aura: '#6EE7B7 (Emerald Sprout)',
    },
  };

  const currentScenario = scenarioMap[selectedMood];
  const recommendedSoundscape = getRecommendedSoundscapeForMood(selectedMood);

  const handleCopyCopywriting = () => {
    navigator.clipboard.writeText(`"${currentScenario.speech}" - ${currentScenario.subtext}`);
    setCopiedText(true);
    setTimeout(() => setCopiedText(false), 2000);
  };

  const handleCopyAudioSpec = () => {
    const text = `Soundscape Token: ${activeSoundToken.name} (${activeSoundToken.musicalKey})\nTrigger: ${activeSoundToken.triggerDescription}\nEnvelope: ${activeSoundToken.adsr.attack}, ${activeSoundToken.adsr.decay}, ${activeSoundToken.adsr.release}\nImplementation: ${activeSoundToken.agentImplementationSpec}`;
    navigator.clipboard.writeText(text);
    setCopiedAudioSpec(true);
    setTimeout(() => setCopiedAudioSpec(false), 2000);
  };

  return (
    <div className="space-y-8">
      {/* 1. MAIN MASCOT SIMULATOR CARD */}
      <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm overflow-hidden">
        {/* Header bar */}
        <div className="px-6 py-4 border-b border-stone-100 flex flex-wrap items-center justify-between gap-4 bg-stone-50/50">
          <div>
            <h2 className="text-lg font-semibold text-stone-900 tracking-tight">Interactive Mascot Simulator</h2>
            <p className="text-xs text-stone-500 mt-0.5">
              Test Lumi's live emotional expressions, speech copy, and supportive reaction rules
            </p>
          </div>
          <div className="flex items-center gap-3">
            {/* Auto Play Sound Toggle */}
            <button
              onClick={() => setAutoPlaySound(!autoPlaySound)}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition-colors cursor-pointer ${
                autoPlaySound
                  ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                  : 'bg-stone-100 text-stone-500 border-stone-200'
              }`}
              title="Toggle automatic audio chime on mood switch"
            >
              {autoPlaySound ? <Volume2 className="w-3.5 h-3.5" /> : <VolumeX className="w-3.5 h-3.5" />}
              <span>{autoPlaySound ? 'Soundscapes On' : 'Muted'}</span>
            </button>
            <div className="flex items-center gap-2 text-xs text-stone-600 bg-white px-3 py-1.5 rounded-full border border-stone-200/80 shadow-2xs">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              <span>Interactive Prototype</span>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-0">
          {/* Scenario Selection Column */}
          <div className="lg:col-span-5 p-6 border-b lg:border-b-0 lg:border-r border-stone-100 bg-stone-50/30 flex flex-col justify-between">
            <div>
              <div className="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-3">
                Trigger a Detox Scenario
              </div>
              <div className="space-y-2">
                {(Object.keys(scenarioMap) as MascotMood[]).map((moodKey) => {
                  const item = scenarioMap[moodKey];
                  const isActive = selectedMood === moodKey;
                  return (
                    <button
                      key={moodKey}
                      onClick={() => handleSelectScenario(moodKey)}
                      className={`w-full text-left px-3.5 py-3 rounded-2xl transition-all flex items-center justify-between group cursor-pointer ${
                        isActive
                          ? 'bg-stone-900 text-white shadow-sm'
                          : 'bg-white hover:bg-stone-100/80 text-stone-700 border border-stone-200/60'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className={`p-2 rounded-xl transition-colors ${
                            isActive ? 'bg-stone-800 text-white' : 'bg-stone-100 text-stone-600'
                          }`}
                        >
                          {item.icon}
                        </div>
                        <div>
                          <div className="text-sm font-semibold leading-tight">{item.label}</div>
                          <div
                            className={`text-xs mt-0.5 line-clamp-1 ${
                              isActive ? 'text-stone-300' : 'text-stone-400'
                            }`}
                          >
                            {item.context}
                          </div>
                        </div>
                      </div>
                      <span
                        className={`text-xs font-mono px-2 py-0.5 rounded-full ${
                          isActive ? 'bg-stone-800 text-stone-300' : 'text-stone-400'
                        }`}
                      >
                        {moodKey.replace('_', ' ')}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Quick Pet Hint */}
            <div className="mt-6 pt-4 border-t border-stone-200/60 text-xs text-stone-500 flex items-center justify-between">
              <span>Tip: Tap on Lumi directly to pet and trigger affection!</span>
              <Heart className="w-3.5 h-3.5 text-rose-400 fill-rose-400" />
            </div>
          </div>

          {/* Live Mascot Stage Column */}
          <div className="lg:col-span-7 p-6 md:p-8 flex flex-col items-center justify-center min-h-[440px] relative bg-radial from-stone-50/80 via-white to-stone-50/30">
            {/* Top Quick Actions */}
            <div className="w-full flex items-center justify-between mb-4">
              <span className="text-xs font-medium text-stone-500">
                Active State:{' '}
                <span className="font-semibold text-stone-800 capitalize">
                  {selectedMood.replace('_', ' ')}
                </span>
              </span>
              <button
                onClick={handleCopyCopywriting}
                className="text-xs font-medium text-stone-600 hover:text-stone-900 flex items-center gap-1.5 bg-stone-100 hover:bg-stone-200/70 px-3 py-1.5 rounded-lg transition-colors cursor-pointer"
              >
                {copiedText ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedText ? 'Copied Script!' : 'Copy Script'}</span>
              </button>
            </div>

            {/* Stage Area */}
            <div className="py-4 flex flex-col items-center">
              <MascotCharacter
                mood={selectedMood}
                size="hero"
                speechText={currentScenario.speech}
                subtext={currentScenario.subtext}
                onPet={() => {
                  const dewdrop = SOUNDSCAPE_TOKENS.find((t) => t.id === 'dewdrop_water_pluck');
                  if (dewdrop && autoPlaySound) {
                    playAudioForToken(dewdrop);
                  }
                  if (selectedMood !== 'celebrating') {
                    triggerConfetti();
                  }
                }}
              />
            </div>

            {/* SUGGESTED AUDITORY SOUNDSCAPE BANNER (FEATURE REQUEST) */}
            <div className="w-full mt-4 p-4 rounded-2xl bg-gradient-to-r from-amber-50/80 via-emerald-50/60 to-purple-50/60 border border-stone-200/80 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-2xs">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-white rounded-xl text-amber-700 shadow-2xs border border-amber-200/60">
                  <Music className="w-4 h-4" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] uppercase font-bold tracking-wider text-stone-400">
                      Suggested Soundscape Cue
                    </span>
                    <span className="text-[10px] font-mono text-emerald-800 bg-emerald-100/70 px-1.5 py-0.5 rounded">
                      {recommendedSoundscape.musicalKey}
                    </span>
                  </div>
                  <div className="text-xs font-bold text-stone-900 mt-0.5">
                    {recommendedSoundscape.name}
                  </div>
                  <p className="text-[11px] text-stone-500 line-clamp-1 mt-0.5">
                    {recommendedSoundscape.triggerDescription}
                  </p>
                </div>
              </div>

              {/* Play Auditory Preview Button */}
              <button
                onClick={() => playAudioForToken(recommendedSoundscape)}
                className={`px-3.5 py-2 rounded-xl text-xs font-semibold flex items-center gap-2 shadow-xs transition-all cursor-pointer shrink-0 ${
                  playingTokenId === recommendedSoundscape.id
                    ? 'bg-emerald-700 text-white scale-102 ring-2 ring-emerald-300'
                    : 'bg-stone-900 text-white hover:bg-stone-800 active:scale-98'
                }`}
                aria-label={`Play auditory preview: ${recommendedSoundscape.name}`}
              >
                <Play className={`w-3.5 h-3.5 ${playingTokenId === recommendedSoundscape.id ? 'fill-white animate-pulse' : 'fill-white'}`} />
                <span>{playingTokenId === recommendedSoundscape.id ? 'Chiming...' : 'Preview Tone'}</span>
              </button>
            </div>

            {/* Behavioral Specs Ribbon */}
            <div className="w-full mt-4 grid grid-cols-2 sm:grid-cols-3 gap-2.5 pt-3 border-t border-stone-100">
              <div className="bg-stone-50/80 p-2.5 rounded-xl border border-stone-200/50">
                <span className="text-[10px] uppercase font-bold text-stone-400 block">Ambient Aura</span>
                <span className="text-xs font-mono font-medium text-stone-700">{currentScenario.aura}</span>
              </div>
              <div className="bg-stone-50/80 p-2.5 rounded-xl border border-stone-200/50">
                <span className="text-[10px] uppercase font-bold text-stone-400 block">Haptic Feedback</span>
                <span className="text-xs font-medium text-stone-700">{currentScenario.haptic}</span>
              </div>
              <div className="col-span-2 sm:col-span-1 bg-stone-50/80 p-2.5 rounded-xl border border-stone-200/50">
                <span className="text-[10px] uppercase font-bold text-stone-400 block">Tone Framing</span>
                <span className="text-xs font-medium text-emerald-700">Supportive & Non-punitive</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 2. AUDITORY SOUNDSCAPE TOKENS PALETTE SECTION */}
      <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
        <div className="flex flex-wrap items-center justify-between gap-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-amber-50 rounded-2xl text-amber-700">
              <Headphones className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-stone-900 tracking-tight">
                Auditory Soundscape Token Library
              </h3>
              <p className="text-xs text-stone-500 mt-0.5">
                Parasympathetic acoustic cues designed to replace anxious slot-machine pings with peaceful mindfulness
              </p>
            </div>
          </div>

          <button
            onClick={handleCopyAudioSpec}
            className="text-xs font-semibold text-stone-700 hover:text-stone-900 flex items-center gap-1.5 bg-stone-100 hover:bg-stone-200 px-3 py-1.5 rounded-xl transition-colors cursor-pointer"
          >
            {copiedAudioSpec ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copiedAudioSpec ? 'Audio Spec Copied!' : 'Copy Audio Specs'}</span>
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {SOUNDSCAPE_TOKENS.map((token) => {
            const isPlaying = playingTokenId === token.id;
            const isSelected = activeSoundToken.id === token.id;

            return (
              <div
                key={token.id}
                onClick={() => {
                  setActiveSoundToken(token);
                  playAudioForToken(token);
                }}
                className={`p-4 rounded-2xl border transition-all cursor-pointer flex flex-col justify-between group ${
                  isSelected
                    ? 'border-emerald-500 bg-emerald-50/20 shadow-xs'
                    : 'border-stone-200/80 bg-stone-50/30 hover:border-stone-400 hover:bg-white'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-[10px] font-mono uppercase tracking-wider text-stone-500 bg-white px-2 py-0.5 rounded border border-stone-200">
                      {token.category}
                    </span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        playAudioForToken(token);
                      }}
                      className={`p-1.5 rounded-lg transition-colors cursor-pointer ${
                        isPlaying
                          ? 'bg-emerald-600 text-white'
                          : 'bg-stone-200/80 text-stone-700 hover:bg-stone-900 hover:text-white'
                      }`}
                      title="Play Sound Preview"
                    >
                      <Play className="w-3 h-3 fill-current" />
                    </button>
                  </div>

                  <h4 className="text-sm font-bold text-stone-900 group-hover:text-emerald-800 transition-colors">
                    {token.name}
                  </h4>
                  <div className="text-[11px] font-mono text-emerald-700 mt-0.5">
                    {token.musicalKey}
                  </div>
                  <p className="text-xs text-stone-500 mt-2 leading-relaxed">
                    {token.psychoacousticGoal}
                  </p>
                </div>

                <div className="mt-4 pt-3 border-t border-stone-200/60 text-[10px] text-stone-400 font-mono flex items-center justify-between">
                  <span>Attack: {token.adsr.attack}</span>
                  <span>Tail: {token.adsr.release}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
