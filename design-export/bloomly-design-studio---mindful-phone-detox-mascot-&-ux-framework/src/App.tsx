import React, { useEffect, useMemo, useRef, useState } from 'react';
import confetti from 'canvas-confetti';
import {
  AlarmClock,
  ArrowLeft,
  BadgeCheck,
  Bell,
  Check,
  ChevronRight,
  Clock3,
  Flower2,
  Headphones,
  Heart,
  Leaf,
  Pause,
  Play,
  RotateCcw,
  Shield,
  Sparkles,
  Sprout,
  Volume1,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { MascotCharacter } from './components/MascotCharacter';
import type { MascotMood } from './design-system/mascot-engine';
import { calculateGardenProgress } from './design-system/mascot-engine';
import { SOUNDSCAPE_TOKENS } from './design-system/soundscape';
import { playSoundscapeToken, startAmbientSoundscape } from './utils/audio-synthesizer';

type TabId = 'oasis' | 'friction' | 'focus' | 'garden';
type ScreenId = TabId | 'celebration';
type BadgeId = 'seedling' | 'young-sprout' | 'flower-bud' | 'golden-blossom';
type AmbientId = 'forest_rain' | 'gentle_stream' | 'soft_drone';
type FocusSession = { durationMinutes: number; endsAt: number | null; remainingSeconds: number };

interface AppData {
  version: 1;
  dayKey: string;
  screenMinutes: number;
  offlineMinutes: number;
  focusMinutes: number;
  streak: number;
  streakDayKey: string;
  seeds: number;
  mindfulPoints: number;
  dailyLimitMinutes: number;
  unlockedBadges: BadgeId[];
  shieldWeekKey: string;
  shieldsUsed: number;
  sessionsCompleted: number;
  focusSession: FocusSession | null;
}

const STORAGE_KEY = 'bloomly.app.v1';
const BADGES: { id: BadgeId; name: string; description: string; minutes: number; icon: string }[] = [
  { id: 'seedling', name: 'Seedling', description: 'A mindful beginning', minutes: 0, icon: '🌱' },
  { id: 'young-sprout', name: 'Young Sprout', description: '60 focused minutes', minutes: 60, icon: '🌿' },
  { id: 'flower-bud', name: 'Flower Bud', description: '2 hours of focus', minutes: 120, icon: '🌷' },
  { id: 'golden-blossom', name: 'Golden Blossom', description: '5 hours of focus', minutes: 300, icon: '🌼' },
];
const APPS = ['Instagram', 'TikTok', 'YouTube'];
const AMBIENTS: { id: AmbientId; label: string; description: string }[] = [
  { id: 'forest_rain', label: 'Forest Rain', description: 'A soft, steady rainfall' },
  { id: 'gentle_stream', label: 'Gentle Stream', description: 'A quiet, flowing hush' },
  { id: 'soft_drone', label: 'Soft Drone', description: 'A warm singing-bowl tone' },
];
const FOCUS_LENGTHS = [15, 25, 45];
const VOICE_STORAGE_KEY = 'bloomly.lumi-voice';

function dateKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function weekKey(date: Date): string {
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return dateKey(monday);
}

function initialData(): AppData {
  const now = new Date();
  return {
    version: 1,
    dayKey: dateKey(now),
    screenMinutes: 80,
    offlineMinutes: 105,
    focusMinutes: 0,
    streak: 1,
    streakDayKey: dateKey(now),
    seeds: 20,
    mindfulPoints: 0,
    dailyLimitMinutes: 180,
    unlockedBadges: ['seedling'],
    shieldWeekKey: weekKey(now),
    shieldsUsed: 0,
    sessionsCompleted: 0,
    focusSession: null,
  };
}

function validFocusSession(value: unknown): FocusSession | null {
  if (!value || typeof value !== 'object') return null;
  const session = value as Partial<FocusSession>;
  if (
    !FOCUS_LENGTHS.includes(session.durationMinutes as number) ||
    typeof session.remainingSeconds !== 'number' ||
    !Number.isFinite(session.remainingSeconds) ||
    session.remainingSeconds < 0 ||
    (session.endsAt !== null && (typeof session.endsAt !== 'number' || !Number.isFinite(session.endsAt)))
  ) return null;
  return {
    durationMinutes: session.durationMinutes as number,
    endsAt: session.endsAt ?? null,
    remainingSeconds: Math.floor(session.remainingSeconds),
  };
}

function loadData(): AppData {
  const fallback = initialData();
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return fallback;
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return fallback;
    const saved = parsed as Partial<AppData>;
    if (
      saved.version !== 1 ||
      typeof saved.screenMinutes !== 'number' ||
      typeof saved.offlineMinutes !== 'number' ||
      typeof saved.focusMinutes !== 'number' ||
      typeof saved.dailyLimitMinutes !== 'number' ||
      !Array.isArray(saved.unlockedBadges)
    ) return fallback;

    const now = new Date();
    const next: AppData = {
      ...fallback,
      ...saved,
      dayKey: typeof saved.dayKey === 'string' ? saved.dayKey : fallback.dayKey,
      shieldWeekKey: typeof saved.shieldWeekKey === 'string' ? saved.shieldWeekKey : fallback.shieldWeekKey,
      screenMinutes: Math.max(0, Math.floor(saved.screenMinutes)),
      offlineMinutes: Math.max(0, Math.floor(saved.offlineMinutes)),
      focusMinutes: Math.max(0, Math.floor(saved.focusMinutes)),
      streak: typeof saved.streak === 'number' && Number.isFinite(saved.streak) ? Math.max(0, Math.floor(saved.streak)) : fallback.streak,
      dailyLimitMinutes: [120, 150, 180, 240, 300].includes(saved.dailyLimitMinutes) ? saved.dailyLimitMinutes : fallback.dailyLimitMinutes,
      seeds: typeof saved.seeds === 'number' && Number.isFinite(saved.seeds) ? Math.max(0, Math.floor(saved.seeds)) : fallback.seeds,
      mindfulPoints: typeof saved.mindfulPoints === 'number' && Number.isFinite(saved.mindfulPoints) ? Math.max(0, Math.floor(saved.mindfulPoints)) : fallback.mindfulPoints,
      shieldsUsed: typeof saved.shieldsUsed === 'number' && Number.isFinite(saved.shieldsUsed) ? Math.min(2, Math.max(0, Math.floor(saved.shieldsUsed))) : fallback.shieldsUsed,
      sessionsCompleted: typeof saved.sessionsCompleted === 'number' && Number.isFinite(saved.sessionsCompleted) ? Math.max(0, Math.floor(saved.sessionsCompleted)) : fallback.sessionsCompleted,
      unlockedBadges: saved.unlockedBadges.filter((id): id is BadgeId =>
        BADGES.some((badge) => badge.id === id),
      ),
      focusSession: validFocusSession(saved.focusSession),
    };
    if (typeof saved.streakDayKey === 'string') next.streakDayKey = saved.streakDayKey;
    if (next.dayKey !== dateKey(now)) {
      next.dayKey = dateKey(now);
      next.screenMinutes = 0;
      next.offlineMinutes = 0;
      next.focusMinutes = 0;
      next.focusSession = null;
    }
    if (next.shieldWeekKey !== weekKey(now)) {
      next.shieldWeekKey = weekKey(now);
      next.shieldsUsed = 0;
    }
    return next;
  } catch {
    return fallback;
  }
}

function formatDuration(totalSeconds: number): string {
  const seconds = Math.max(0, totalSeconds);
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

function formatMinutes(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return hours ? `${hours}h ${String(remainder).padStart(2, '0')}m` : `${remainder}m`;
}

function vibrate(pattern: number | number[]) {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') navigator.vibrate(pattern);
}

function playToken(tokenId: string) {
  const token = SOUNDSCAPE_TOKENS.find(({ id }) => id === tokenId);
  if (token) playSoundscapeToken(token);
}

function readVoicePreference(): boolean {
  try {
    return localStorage.getItem(VOICE_STORAGE_KEY) === 'on';
  } catch {
    return false;
  }
}

function speakLumi(text: string): boolean {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) return false;
  const speech = window.speechSynthesis;
  speech.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = navigator.language || 'en-US';
  utterance.rate = 0.88;
  utterance.pitch = 1.12;
  utterance.volume = 0.82;
  const voices = speech.getVoices();
  const englishVoices = voices.filter((voice) => voice.lang.toLowerCase().startsWith('en'));
  utterance.voice = englishVoices.find((voice) => /samantha|aria|jenny|serena|female/i.test(voice.name))
    ?? englishVoices.find((voice) => voice.default)
    ?? englishVoices[0]
    ?? null;
  speech.speak(utterance);
  return true;
}

function App() {
  const [data, setData] = useState<AppData>(loadData);
  const [screen, setScreen] = useState<ScreenId>('oasis');
  const [mascotMood, setMascotMood] = useState<MascotMood>('idle_happy');
  const [selectedApp, setSelectedApp] = useState(APPS[0]);
  const [breathRemaining, setBreathRemaining] = useState(5);
  const [focusLength, setFocusLength] = useState(25);
  const [timerRemaining, setTimerRemaining] = useState(25 * 60);
  const [ambient, setAmbient] = useState<AmbientId>('forest_rain');
  const [ambientEnabled, setAmbientEnabled] = useState(false);
  const [lumiVoiceEnabled, setLumiVoiceEnabled] = useState(readVoicePreference);
  const [toast, setToast] = useState('');
  const [saveError, setSaveError] = useState(false);
  const completionLock = useRef<number | null>(null);
  const ambientStop = useRef<(() => void) | null>(null);
  const toastTimeout = useRef<number | undefined>(undefined);

  const remainingShields = Math.max(0, 2 - data.shieldsUsed);
  const garden = useMemo(() => calculateGardenProgress(data.focusMinutes, 300), [data.focusMinutes]);
  const focusSession = data.focusSession;
  const focusIsRunning = Boolean(focusSession?.endsAt);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
      setSaveError(false);
    } catch {
      setSaveError(true);
    }
  }, [data]);

  useEffect(() => () => {
    ambientStop.current?.();
    window.clearTimeout(toastTimeout.current);
    if ('speechSynthesis' in window) window.speechSynthesis.cancel();
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(VOICE_STORAGE_KEY, lumiVoiceEnabled ? 'on' : 'off');
    } catch {
      if (lumiVoiceEnabled) notify('Lumi’s voice setting could not be saved on this device.');
    }
  }, [lumiVoiceEnabled]);

  useEffect(() => {
    if (!lumiVoiceEnabled) {
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
      return;
    }

    const narration = {
      oasis: 'Hello, friend. You have lived a little more of your real life today. Every step counts, and I am right here with you.',
      friction: `Let us take a breath together. What is your heart hoping to find before opening ${selectedApp}? You are in control.`,
      focus: 'We are resting our minds together. Breathe in slowly, and breathe out softly. There is no need to rush.',
      garden: `Look how we are growing. Day ${data.streak} of intentional living. Every gentle step helps our garden bloom.`,
      celebration: 'You did it. A beautiful pocket of presence, made by you. I am so proud of the room you made to bloom.',
    }[screen];
    const timeout = window.setTimeout(() => speakLumi(narration), 180);
    return () => {
      window.clearTimeout(timeout);
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
    };
  }, [lumiVoiceEnabled, screen, selectedApp]);

  useEffect(() => {
    if (screen !== 'friction') return;
    const startedAt = Date.now();
    setBreathRemaining(5);
    const interval = window.setInterval(() => {
      setBreathRemaining(Math.max(0, 5 - Math.floor((Date.now() - startedAt) / 1000)));
    }, 200);
    return () => window.clearInterval(interval);
  }, [screen, selectedApp]);

  useEffect(() => {
    if (!focusSession?.endsAt) {
      setTimerRemaining(focusSession?.remainingSeconds ?? focusLength * 60);
      return;
    }
    const endAt = focusSession.endsAt;
    const tick = () => {
      const remaining = Math.max(0, Math.ceil((endAt - Date.now()) / 1000));
      setTimerRemaining(remaining);
      if (remaining === 0 && completionLock.current !== endAt) {
        completionLock.current = endAt;
        completeFocus(endAt);
      }
    };
    tick();
    const interval = window.setInterval(tick, 250);
    return () => window.clearInterval(interval);
  }, [focusSession?.endsAt, focusSession?.remainingSeconds, focusLength]);

  function notify(message: string) {
    setToast(message);
    window.clearTimeout(toastTimeout.current);
    toastTimeout.current = window.setTimeout(() => setToast(''), 3200);
  }

  function openTab(tab: TabId) {
    setScreen(tab);
    if (tab === 'oasis') setMascotMood('idle_happy');
    if (tab === 'friction') setMascotMood('gentle_nudge');
    if (tab === 'focus') setMascotMood(focusSession ? 'zen_focus' : 'idle_happy');
    if (tab === 'garden') setMascotMood('watering_plant');
    vibrate(10);
  }

  function toggleLumiVoice() {
    if (!lumiVoiceEnabled && !('speechSynthesis' in window)) {
      notify('Spoken voice is not available in this browser. Lumi’s messages are still here to read.');
      return;
    }
    setLumiVoiceEnabled((enabled) => !enabled);
  }

  function completeFocus(endAt: number) {
    const activeSession = data.focusSession;
    if (!activeSession || activeSession.endsAt !== endAt) return;
    ambientStop.current?.();
    ambientStop.current = null;
    setAmbientEnabled(false);
    const nextFocusMinutes = data.focusMinutes + activeSession.durationMinutes;
    const newlyUnlocked = BADGES
      .filter((badge) => nextFocusMinutes >= badge.minutes && !data.unlockedBadges.includes(badge.id))
      .map((badge) => badge.id);
    setData((current) => {
      if (!current.focusSession || current.focusSession.endsAt !== endAt) return current;
      const minutes = current.focusSession.durationMinutes;
      const focusMinutes = current.focusMinutes + minutes;
      return {
        ...current,
        focusMinutes,
        offlineMinutes: current.offlineMinutes + minutes,
        seeds: current.seeds + 20,
        sessionsCompleted: current.sessionsCompleted + 1,
        streak: current.streakDayKey === current.dayKey ? current.streak : current.streak + 1,
        streakDayKey: current.dayKey,
        unlockedBadges: [...current.unlockedBadges, ...newlyUnlocked],
        focusSession: null,
      };
    });
    setMascotMood('celebrating');
    setScreen('celebration');
    playToken(newlyUnlocked.length ? 'zen_wind_chime' : 'bell_528_harmony');
    vibrate([30, 60, 40]);
    confetti({
      particleCount: newlyUnlocked.length ? 90 : 58,
      spread: 76,
      startVelocity: 26,
      origin: { y: 0.62 },
      colors: ['#4ADE80', '#FDE047', '#F472B6', '#86EFAC', '#DDD6FE'],
      shapes: ['circle', 'star'],
      scalar: 0.9,
    });
    notify(newlyUnlocked.length ? 'A new botanical badge is blooming!' : 'A lovely pocket of presence, just for you.');
  }

  function startFocus() {
    const endsAt = Date.now() + focusLength * 60_000;
    completionLock.current = null;
    setTimerRemaining(focusLength * 60);
    setData((current) => ({
      ...current,
      focusSession: { durationMinutes: focusLength, endsAt, remainingSeconds: focusLength * 60 },
    }));
    setMascotMood('zen_focus');
    setAmbientEnabled(true);
    setScreen('focus');
    try {
      ambientStop.current?.();
      ambientStop.current = startAmbientSoundscape(ambient);
    } catch {
      setAmbientEnabled(false);
      notify('Sound could not start. Your quiet focus session is ready.');
    }
    playToken('singing_bowl_drone');
    vibrate(60);
  }

  function pauseFocus() {
    if (!focusSession?.endsAt) return;
    const remainingSeconds = Math.max(0, Math.ceil((focusSession.endsAt - Date.now()) / 1000));
    setData((current) => current.focusSession?.endsAt === focusSession.endsAt
      ? { ...current, focusSession: { ...current.focusSession, endsAt: null, remainingSeconds } }
      : current);
    setTimerRemaining(remainingSeconds);
    ambientStop.current?.();
    ambientStop.current = null;
    setAmbientEnabled(false);
    notify('Your focus is gently paused. You can return whenever you like.');
  }

  function resumeFocus() {
    if (!focusSession || focusSession.endsAt) return;
    const endsAt = Date.now() + focusSession.remainingSeconds * 1000;
    completionLock.current = null;
    setData((current) => current.focusSession
      ? { ...current, focusSession: { ...current.focusSession, endsAt } }
      : current);
    setAmbientEnabled(true);
    try {
      ambientStop.current?.();
      ambientStop.current = startAmbientSoundscape(ambient);
    } catch {
      setAmbientEnabled(false);
      notify('Sound could not start. Your focus can continue quietly.');
    }
  }

  function endFocusEarly() {
    setData((current) => ({ ...current, focusSession: null }));
    setMascotMood('idle_happy');
    setAmbientEnabled(false);
    ambientStop.current?.();
    ambientStop.current = null;
    setTimerRemaining(focusLength * 60);
    notify('You showed up for yourself. That counts.');
  }

  function changeAmbient(next: AmbientId) {
    setAmbient(next);
    if (!ambientEnabled) {
      playToken(next === 'soft_drone' ? 'singing_bowl_drone' : 'dewdrop_water_pluck');
      return;
    }
    try {
      ambientStop.current?.();
      ambientStop.current = startAmbientSoundscape(next);
    } catch {
      setAmbientEnabled(false);
      notify('This soundscape is not available right now.');
    }
  }

  function toggleAmbient() {
    if (ambientEnabled) {
      ambientStop.current?.();
      ambientStop.current = null;
      setAmbientEnabled(false);
      return;
    }
    try {
      ambientStop.current?.();
      ambientStop.current = startAmbientSoundscape(ambient);
      setAmbientEnabled(true);
    } catch {
      notify('Sound could not start on this device.');
    }
  }

  function putDownPhone() {
    setData((current) => ({ ...current, mindfulPoints: current.mindfulPoints + 5, offlineMinutes: current.offlineMinutes + 5 }));
    playToken('kalimba_pentatonic_sparkle');
    setMascotMood('celebrating');
    setScreen('oasis');
    notify('+5 mindful points. Proud of your awareness.');
  }

  function continueMindfully() {
    const usedShield = data.screenMinutes <= data.dailyLimitMinutes
      && data.screenMinutes + 5 > data.dailyLimitMinutes
      && data.shieldsUsed < 2;
    setData((current) => {
      const screenMinutes = current.screenMinutes + 5;
      const crossedLimit = current.screenMinutes <= current.dailyLimitMinutes && screenMinutes > current.dailyLimitMinutes;
      return {
        ...current,
        screenMinutes,
        shieldsUsed: crossedLimit && current.shieldsUsed < 2 ? current.shieldsUsed + 1 : current.shieldsUsed,
      };
    });
    setMascotMood('comforting');
    setScreen('oasis');
    playToken('dewdrop_water_pluck');
    vibrate(40);
    notify(usedShield
      ? 'Lumi tucked a Seedling Shield around your garden today. Take what you need.'
      : 'Life happens. You are in control, and Lumi is right here.');
  }

  function useShield() {
    if (!remainingShields) return;
    setData((current) => ({ ...current, shieldsUsed: Math.min(2, current.shieldsUsed + 1) }));
    setMascotMood('comforting');
    playToken('singing_bowl_drone');
    notify('A Seedling Shield is resting over your garden. Your streak is safe.');
  }

  function waterGarden() {
    setMascotMood('watering_plant');
    playToken('kalimba_pentatonic_sparkle');
    if (data.streak > 0 && data.streak % 7 === 0) playToken('zen_wind_chime');
    vibrate([10, 10]);
    notify(`Day ${data.streak} of intentional living. Every step counts.`);
  }

  function petLumi() {
    playToken('dewdrop_water_pluck');
    vibrate(10);
  }

  function startBedtime() {
    setMascotMood('sleeping');
    playToken('singing_bowl_drone');
    vibrate(120);
    notify('A soft wind-down is here when you’re ready to rest.');
  }

  const usedPercent = Math.min(100, Math.round((data.screenMinutes / data.dailyLimitMinutes) * 100));
  const ringStyle = { '--ring-progress': `${usedPercent * 3.6}deg` } as React.CSSProperties;
  const activeTab = screen === 'celebration' ? 'oasis' : screen;
  const tabs: { id: TabId; label: string; icon: React.ReactNode }[] = [
    { id: 'oasis', label: 'Oasis', icon: <Flower2 /> },
    { id: 'friction', label: 'Pause', icon: <Heart /> },
    { id: 'focus', label: 'Focus', icon: <AlarmClock /> },
    { id: 'garden', label: 'Garden', icon: <Sprout /> },
  ];

  return (
    <div className="app-backdrop">
      <div className="app-shell">
        <header className="app-header">
          <a className="wordmark" href="#oasis" onClick={(event) => { event.preventDefault(); openTab('oasis'); }}>
            <span className="wordmark-mark" aria-hidden="true"><Sprout size={19} /></span>
            <span>Bloomly</span>
          </a>
          <div className="header-streak" aria-label={`${data.streak} day mindful streak`}>
            <span aria-hidden="true">✦</span>
            <span>{data.streak} day{data.streak === 1 ? '' : 's'}</span>
          </div>
          <button
            className={`voice-toggle ${lumiVoiceEnabled ? 'voice-on' : ''}`}
            onClick={toggleLumiVoice}
            role="switch"
            aria-checked={lumiVoiceEnabled}
            aria-label={`Lumi voice ${lumiVoiceEnabled ? 'on' : 'off'}`}
            title={`Lumi voice ${lumiVoiceEnabled ? 'on' : 'off'}`}
          >
            {lumiVoiceEnabled ? <Volume1 size={17} /> : <VolumeX size={17} />}
          </button>
        </header>

        <main className="app-main" key={screen}>
          {screen === 'oasis' && (
            <section className="screen oasis-screen" aria-labelledby="oasis-title">
              <div className="greeting">
                <p className="eyebrow">{new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
                <h1 id="oasis-title">A little more room to bloom.</h1>
                <p className="body-copy">You’ve lived <strong>{formatMinutes(data.offlineMinutes)}</strong> of real life today. Every step counts.</p>
              </div>

              <button className="lumi-stage" onClick={petLumi} aria-label="Pet Lumi for a gentle moment">
                <span className="stage-spark stage-spark-one">✦</span>
                <span className="stage-spark stage-spark-two">✿</span>
                <MascotCharacter
                  mood={mascotMood}
                  size="lg"
                  showSpeechBubble
                  speechText={mascotMood === 'comforting'
                    ? 'Life happens. I’m still right here with you.'
                    : mascotMood === 'sleeping'
                      ? 'Shh… the stars are out. Let’s let our eyes rest.'
                      : 'Your real life is waiting outside. Shall we make a little space?'}
                  isInteractive={false}
                />
                <span className="pet-hint">Tap Lumi for a little love</span>
              </button>

              <div className="quota-card">
                <div className="quota-ring" style={ringStyle} role="img" aria-label={`${usedPercent}% of daily mindful screen limit used`}>
                  <div className="quota-ring-inner">
                    <span className="quota-number">{usedPercent}%</span>
                    <span className="quota-caption">of today’s<br />screen time</span>
                  </div>
                </div>
                <div className="quota-copy">
                  <span className="card-kicker">Your mindful limit</span>
                  <h2>{formatMinutes(data.screenMinutes)} <span>of {formatMinutes(data.dailyLimitMinutes)}</span></h2>
                  <p>{Math.max(0, data.dailyLimitMinutes - data.screenMinutes)} minutes of gentle space left today.</p>
                  <label className="limit-control">
                    <span>Daily allowance</span>
                    <select
                      aria-label="Daily screen time allowance"
                      value={data.dailyLimitMinutes}
                      onChange={(event) => setData((current) => ({ ...current, dailyLimitMinutes: Number(event.target.value) }))}
                    >
                      {[120, 150, 180, 240, 300].map((minutes) => (
                        <option key={minutes} value={minutes}>{formatMinutes(minutes)}</option>
                      ))}
                    </select>
                  </label>
                </div>
              </div>

              <button className="primary-action" onClick={() => openTab('focus')}>
                <span className="action-icon"><Play size={17} fill="currentColor" /></span>
                <span><strong>Start 25m Calmer Focus</strong><small>A gentle pocket of presence</small></span>
                <ChevronRight className="action-chevron" size={19} />
              </button>

              <div className="quick-grid">
                <button className="quick-card" onClick={() => openTab('friction')}>
                  <span className="quick-icon peach"><Heart size={17} /></span>
                  <span><strong>Take a pause</strong><small>5 gentle seconds</small></span>
                  <ChevronRight size={17} />
                </button>
                <div className="quick-card quick-static">
                  <span className="quick-icon sage"><Shield size={17} /></span>
                  <span><strong>{remainingShields} Seedling Shields</strong><small>Restored each week</small></span>
                </div>
                <button className="quick-card" onClick={startBedtime}>
                  <span className="quick-icon lavender"><Bell size={17} /></span>
                  <span><strong>Wind down</strong><small>A softer bedtime</small></span>
                  <ChevronRight size={17} />
                </button>
              </div>

              <div className="tiny-stats" aria-label="Today's mindful activity">
                <div><span className="tiny-stat-icon"><Clock3 size={15} /></span><strong>{formatMinutes(data.focusMinutes)}</strong><small>in focus</small></div>
                <div><span className="tiny-stat-icon"><Sparkles size={15} /></span><strong>{data.seeds}</strong><small>sprout seeds</small></div>
                <div><span className="tiny-stat-icon"><Heart size={15} /></span><strong>{data.mindfulPoints}</strong><small>mindful points</small></div>
              </div>
            </section>
          )}

          {screen === 'friction' && (
            <section className="screen friction-screen" aria-labelledby="friction-title">
              <button className="back-link" onClick={() => openTab('oasis')}><ArrowLeft size={17} /> Back to your oasis</button>
              <div className="friction-heading">
                <span className="eyebrow peach-text">A mindful moment</span>
                <h1 id="friction-title">Before you open {selectedApp}…</h1>
                <p>There’s no wrong choice. Let’s make a little space to notice what you need.</p>
              </div>
              <label className="app-select-label" htmlFor="app-choice">Choose an app to pause before</label>
              <select id="app-choice" className="app-choice" value={selectedApp} onChange={(event) => setSelectedApp(event.target.value)}>
                {APPS.map((app) => <option key={app}>{app}</option>)}
              </select>
              <div className="breath-panel">
                <div className={`breath-orbit ${breathRemaining === 0 ? 'breath-ready' : ''}`}>
                  <div className="breath-core">
                    <span>{breathRemaining > 0 ? breathRemaining : '♡'}</span>
                    <small>{breathRemaining > 0 ? 'seconds' : 'you’re here'}</small>
                  </div>
                </div>
                <span className="breath-instruction">
                  {breathRemaining === 0 ? 'A breath made room for a choice.' : breathRemaining > 2 ? 'Breathe in gently' : 'And slowly breathe out'}
                </span>
              </div>
              <div className="friction-checkin">
                <MascotCharacter mood="gentle_nudge" size="sm" showSpeechBubble={false} isInteractive={false} />
                <p><strong>What is your heart hoping to find right now?</strong><span>Notice with kindness. You are in control.</span></p>
              </div>
              <div className="friction-actions">
                <button className="primary-action" onClick={putDownPhone}>
                  <span className="action-icon"><Check size={18} /></span>
                  <span><strong>Put Down Phone</strong><small>+5 mindful points</small></span>
                  <ChevronRight className="action-chevron" size={19} />
                </button>
                <button className="gentle-action" onClick={continueMindfully}>
                  <span><strong>I really need to use it</strong><small>Zero guilt. You’re in control.</small></span>
                  <ChevronRight size={18} />
                </button>
              </div>
              <p className="quiet-note"><Shield size={14} /> Your choices are yours. This gentle pause never locks you out.</p>
              <p className="preview-note">App-open pauses are previewed here. Detecting real app launches requires native device permissions.</p>
            </section>
          )}

          {screen === 'focus' && (
            <section className="screen focus-screen" aria-labelledby="focus-title">
              <span className="eyebrow">Your quiet corner</span>
              <h1 id="focus-title">{focusSession ? 'Resting our minds.' : 'A little time, just for you.'}</h1>
              <p className="body-copy">{focusSession ? 'No need to rush. Lumi is breathing right alongside you.' : 'Choose a soft beginning. You can pause or stop whenever you need.'}</p>
              <div className="focus-mascot">
                <MascotCharacter
                  mood={focusSession ? 'zen_focus' : 'idle_happy'}
                  size="md"
                  showSpeechBubble
                  speechText={focusSession ? 'Breathe in slowly… and breathe out softly.' : 'Let’s make a little room for what matters.'}
                  isInteractive
                  onPet={petLumi}
                />
              </div>
              {!focusSession && (
                <div className="duration-picker" aria-label="Choose focus session length">
                  {FOCUS_LENGTHS.map((minutes) => (
                    <button key={minutes} className={focusLength === minutes ? 'duration-option selected' : 'duration-option'} onClick={() => setFocusLength(minutes)}>
                      {minutes}<small>min</small>
                    </button>
                  ))}
                </div>
              )}
              {focusSession && (
                <div className="focus-clock" aria-live="polite">
                  <span>{formatDuration(timerRemaining)}</span>
                  <small>{focusIsRunning ? 'INHALE · EXHALE' : 'PAUSED, WHENEVER YOU NEED'}</small>
                </div>
              )}
              <div className="breathing-guide" aria-hidden="true"><span>Inhale · 4</span><i /><span>Exhale · 4</span></div>
              <div className="ambient-card">
                <div className="ambient-title">
                  <span className="ambient-icon"><Headphones size={18} /></span>
                  <span><strong>Ambient soundscape</strong><small>Soft, optional sounds for your space</small></span>
                  <button className={`sound-toggle ${ambientEnabled ? 'sound-on' : ''}`} onClick={toggleAmbient} role="switch" aria-checked={ambientEnabled} aria-label="Toggle ambient soundscape">
                    {ambientEnabled ? <Volume2 size={17} /> : <VolumeX size={17} />}
                  </button>
                </div>
                <div className="ambient-options">
                  {AMBIENTS.map((scene) => (
                    <button
                      key={scene.id}
                      className={ambient === scene.id ? 'ambient-option chosen' : 'ambient-option'}
                      title={scene.description}
                      onClick={() => changeAmbient(scene.id)}
                    >{scene.label}</button>
                  ))}
                </div>
              </div>
              <div className="focus-actions">
                {!focusSession && <button className="primary-action centered-action" onClick={startFocus}><Play size={17} fill="currentColor" /> Begin {focusLength} minutes</button>}
                {focusSession && focusIsRunning && <button className="primary-action centered-action" onClick={pauseFocus}><Pause size={17} /> Pause gently</button>}
                {focusSession && !focusIsRunning && <button className="primary-action centered-action" onClick={resumeFocus}><Play size={17} fill="currentColor" /> Return to focus</button>}
                {focusSession && <button className="text-action" onClick={endFocusEarly}><RotateCcw size={15} /> End this session</button>}
              </div>
            </section>
          )}

          {screen === 'garden' && (
            <section className="screen garden-screen" aria-labelledby="garden-title">
              <span className="eyebrow">Your small, lovely steps</span>
              <h1 id="garden-title">Look how we’re growing.</h1>
              <p className="body-copy">There is no perfect streak. Just a garden that keeps welcoming you back.</p>
              <div className="garden-mascot">
                <MascotCharacter
                  mood={mascotMood === 'watering_plant' ? 'watering_plant' : 'idle_happy'}
                  size="sm"
                  speechText={mascotMood === 'watering_plant' ? `Day ${data.streak} of intentional living. Every step counts.` : 'Our garden grows one gentle step at a time.'}
                  showSpeechBubble
                  isInteractive
                  onPet={petLumi}
                />
              </div>
              <div className="garden-hero">
                <div className="garden-plant" aria-hidden="true"><span>✦</span><span>🌱</span><i>✧</i></div>
                <strong>{garden.stageName}</strong>
                <span>{data.focusMinutes} of 300 focus minutes</span>
                <div className="garden-progress"><span style={{ width: `${garden.percentage}%` }} /></div>
                <small>{garden.percentage}% toward your next bloom</small>
              </div>
              <button className="watering-card" onClick={waterGarden}>
                <span className="quick-icon sage"><Sprout size={18} /></span>
                <span><strong>Water today’s seedling</strong><small>Day {data.streak} of intentional living</small></span>
                <ChevronRight size={18} />
              </button>
              <div className="section-heading">
                <div><h2>Seedling Shields</h2><p>Two soft landings, renewed each week.</p></div>
                <span className="shield-count"><Shield size={15} /> {remainingShields} left</span>
              </div>
              <div className="shield-card">
                <div className="shield-illustration"><Shield size={25} /><span>♡</span></div>
                <div><strong>Your garden is protected</strong><p>Busy days happen. A shield keeps your streak safe while you rest and reset.</p></div>
                <button className="outline-action" disabled={!remainingShields} onClick={useShield}>
                  {remainingShields ? 'Use a shield' : 'All tucked in'}
                </button>
              </div>
              <div className="section-heading badge-heading">
                <div><h2>Little milestones</h2><p>Every one is a reason to feel proud.</p></div>
                <BadgeCheck size={20} />
              </div>
              <div className="badge-grid">
                {BADGES.map((badge) => {
                  const unlocked = data.unlockedBadges.includes(badge.id);
                  return (
                    <article className={`badge-card ${unlocked ? 'unlocked' : ''}`} key={badge.id}>
                      <span className="badge-art" aria-hidden="true">{badge.icon}</span>
                      <strong>{badge.name}</strong>
                      <small>{unlocked ? 'Blooming in your garden' : badge.description}</small>
                    </article>
                  );
                })}
              </div>
              <div className="garden-summary"><span><Sparkles size={15} /> {data.seeds} sprout seeds</span><span><Clock3 size={15} /> {data.sessionsCompleted} focus sessions</span></div>
            </section>
          )}

          {screen === 'celebration' && (
            <section className="screen celebration-screen" aria-labelledby="celebration-title">
              <div className="celebration-confetti" aria-hidden="true"><span>✦</span><span>🍃</span><span>✧</span><span>✿</span><span>✦</span></div>
              <span className="eyebrow">A moment worth celebrating</span>
              <h1 id="celebration-title">You made room to bloom.</h1>
              <p className="body-copy">A beautiful pocket of presence, made by you. Your real life is growing brighter.</p>
              <MascotCharacter mood="celebrating" size="hero" showSpeechBubble speechText="You did it! Our garden is blooming." subtext="+20 sprout seeds for mindful presence" isInteractive onPet={petLumi} />
              <div className="celebration-reward"><span>🌱</span><strong>+20 sprout seeds</strong><small>{formatMinutes(data.offlineMinutes)} of real life lived today</small></div>
              <button className="primary-action centered-action" onClick={() => openTab('oasis')}><Leaf size={18} /> Back to your oasis</button>
              <button className="text-action" onClick={() => openTab('garden')}>See your growing garden <ChevronRight size={15} /></button>
            </section>
          )}
        </main>

        <nav className="bottom-nav" aria-label="Main navigation">
          {tabs.map((tab) => (
            <button key={tab.id} className={activeTab === tab.id ? 'nav-item active' : 'nav-item'} onClick={() => openTab(tab.id)} aria-current={activeTab === tab.id ? 'page' : undefined}>
              {tab.icon}<span>{tab.label}</span>
            </button>
          ))}
        </nav>
        <div className="app-safe-space" />
      </div>
      {toast && <div className="toast" role="status"><span className="toast-dot" />{toast}</div>}
      {saveError && <div className="save-notice" role="status">Progress is available this visit, but could not be saved on this device.</div>}
    </div>
  );
}

export default App;
