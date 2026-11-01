import React, { useState, useEffect } from 'react';
import confetti from 'canvas-confetti';
import { MascotCharacter } from './MascotCharacter';
import {
  Sparkles,
  Shield,
  Clock,
  Play,
  RotateCcw,
  CheckCircle2,
  Lock,
  Pause,
  Award,
  ChevronRight,
  Wind,
  Smile,
  Compass,
} from 'lucide-react';

export const PhoneAppMockupViewer: React.FC = () => {
  const [activeScreen, setActiveScreen] = useState<'dashboard' | 'intercept' | 'focus' | 'milestone'>('dashboard');
  
  // Focus session state
  const [focusSeconds, setFocusSeconds] = useState(1500); // 25 mins
  const [isFocusing, setIsFocusing] = useState(false);

  // Intercept breath countdown
  const [breathCountdown, setBreathCountdown] = useState(5);
  const [breathPhase, setBreathPhase] = useState<'breathe_in' | 'hold' | 'breathe_out'>('breathe_in');

  useEffect(() => {
    let timer: NodeJS.Timeout;
    if (isFocusing && focusSeconds > 0) {
      timer = setInterval(() => {
        setFocusSeconds((prev) => prev - 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [isFocusing, focusSeconds]);

  // Breathing timer for intercept
  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (activeScreen === 'intercept' && breathCountdown > 0) {
      interval = setInterval(() => {
        setBreathCountdown((prev) => {
          if (prev <= 1) return 0;
          return prev - 1;
        });
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [activeScreen, breathCountdown]);

  const triggerMilestoneConfetti = () => {
    confetti({
      particleCount: 70,
      spread: 70,
      origin: { y: 0.5 },
      colors: ['#15803D', '#FDE047', '#86EFAC', '#F472B6'],
    });
  };

  const handleScreenSwitch = (screen: 'dashboard' | 'intercept' | 'focus' | 'milestone') => {
    setActiveScreen(screen);
    if (screen === 'intercept') {
      setBreathCountdown(5);
    }
    if (screen === 'milestone') {
      triggerMilestoneConfetti();
    }
  };

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  return (
    <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
      <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
        <div>
          <h2 className="text-xl font-semibold text-stone-900 tracking-tight">
            Mobile Experience Showcase
          </h2>
          <p className="text-sm text-stone-500 mt-1">
            Experience how Lumi integrates natively across core app touchpoints to guide digital detox
          </p>
        </div>

        {/* Screen Switcher Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-stone-100 rounded-2xl border border-stone-200/60 overflow-x-auto max-w-full">
          <button
            onClick={() => handleScreenSwitch('dashboard')}
            className={`px-3.5 py-1.5 text-xs font-semibold rounded-xl whitespace-nowrap transition-all cursor-pointer ${
              activeScreen === 'dashboard'
                ? 'bg-white text-stone-900 shadow-xs'
                : 'text-stone-600 hover:text-stone-900'
            }`}
          >
            1. Daily Oasis
          </button>
          <button
            onClick={() => handleScreenSwitch('intercept')}
            className={`px-3.5 py-1.5 text-xs font-semibold rounded-xl whitespace-nowrap transition-all cursor-pointer ${
              activeScreen === 'intercept'
                ? 'bg-white text-stone-900 shadow-xs'
                : 'text-stone-600 hover:text-stone-900'
            }`}
          >
            2. Mindful Nudge
          </button>
          <button
            onClick={() => handleScreenSwitch('focus')}
            className={`px-3.5 py-1.5 text-xs font-semibold rounded-xl whitespace-nowrap transition-all cursor-pointer ${
              activeScreen === 'focus'
                ? 'bg-white text-stone-900 shadow-xs'
                : 'text-stone-600 hover:text-stone-900'
            }`}
          >
            3. Zen Focus Mode
          </button>
          <button
            onClick={() => handleScreenSwitch('milestone')}
            className={`px-3.5 py-1.5 text-xs font-semibold rounded-xl whitespace-nowrap transition-all cursor-pointer ${
              activeScreen === 'milestone'
                ? 'bg-white text-stone-900 shadow-xs'
                : 'text-stone-600 hover:text-stone-900'
            }`}
          >
            4. Milestone Joy
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
        {/* Mobile Device Mockup Frame */}
        <div className="lg:col-span-6 flex justify-center">
          <div className="w-[340px] h-[670px] bg-stone-900 rounded-[48px] p-3 shadow-2xl border-4 border-stone-800 relative ring-1 ring-stone-950/20">
            {/* Dynamic Island / Speaker */}
            <div className="absolute top-6 left-1/2 -translate-x-1/2 w-28 h-5 bg-black rounded-full z-40 flex items-center justify-center">
              <div className="w-2.5 h-2.5 rounded-full bg-stone-900 border border-stone-800 mr-3" />
              <div className="w-2 h-2 rounded-full bg-blue-950" />
            </div>

            {/* Smartphone Inner Screen Canvas */}
            <div className="w-full h-full bg-[#FAF8F5] rounded-[38px] overflow-hidden flex flex-col justify-between relative pt-8 pb-4 text-stone-900">
              {/* Top Status Bar */}
              <div className="px-6 flex items-center justify-between text-[11px] font-semibold text-stone-600">
                <span>9:41</span>
                <div className="flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500" />
                  <span className="text-[10px]">Lumi Calmer</span>
                </div>
              </div>

              {/* Dynamic Screen Content */}
              <div className="flex-1 overflow-y-auto px-5 py-3">
                {/* SCREEN 1: DAILY DASHBOARD */}
                {activeScreen === 'dashboard' && (
                  <div className="space-y-4">
                    {/* Welcome Header */}
                    <div className="flex items-center justify-between">
                      <div>
                        <span className="text-[11px] font-medium text-stone-400 block">Morning Check-in</span>
                        <h3 className="text-lg font-bold text-stone-900 leading-tight">Peaceful Mind, Alex</h3>
                      </div>
                      <div className="flex items-center gap-1 bg-emerald-50 border border-emerald-200/60 px-2.5 py-1 rounded-full text-emerald-800 text-xs font-semibold">
                        <span>🔥 5 Days</span>
                      </div>
                    </div>

                    {/* Mascot Showcase Card */}
                    <div className="bg-gradient-to-b from-emerald-50/60 to-white p-4 rounded-3xl border border-emerald-100/80 shadow-2xs text-center flex flex-col items-center">
                      <MascotCharacter
                        mood="idle_happy"
                        size="md"
                        showSpeechBubble={false}
                      />
                      <div className="mt-2 text-center">
                        <p className="text-xs font-medium text-stone-800">
                          "You've enjoyed <span className="font-bold text-emerald-700">1h 45m</span> of real life so far today!"
                        </p>
                        <span className="text-[10px] text-stone-400 block mt-0.5">Seedling Stage: Young Sprout (4 Leaves)</span>
                      </div>
                    </div>

                    {/* Today's Garden Progress Meter */}
                    <div className="bg-white p-4 rounded-2xl border border-stone-200/70 shadow-2xs">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-xs font-semibold text-stone-700">Mindful Screen Quota</span>
                        <span className="text-xs font-mono font-bold text-emerald-700">65% Kept</span>
                      </div>
                      <div className="w-full bg-stone-100 h-2.5 rounded-full overflow-hidden">
                        <div className="bg-gradient-to-r from-emerald-400 to-emerald-600 h-full w-[65%] rounded-full" />
                      </div>
                      <div className="flex items-center justify-between mt-2 text-[10px] text-stone-400">
                        <span>Resting: 3h 15m</span>
                        <span>Daily Goal: 4h Max</span>
                      </div>
                    </div>

                    {/* Primary Supportive CTA */}
                    <button
                      onClick={() => handleScreenSwitch('focus')}
                      className="w-full py-3 bg-stone-900 hover:bg-stone-800 text-white rounded-2xl text-xs font-semibold flex items-center justify-center gap-2 shadow-sm transition-transform active:scale-98 cursor-pointer"
                    >
                      <Play className="w-3.5 h-3.5 fill-white" />
                      <span>Start 25m Calmer Focus</span>
                    </button>
                  </div>
                )}

                {/* SCREEN 2: MINDFUL INTERCEPT (GENTLE FRICTION) */}
                {activeScreen === 'intercept' && (
                  <div className="flex flex-col items-center justify-between h-full py-2 text-center">
                    <div className="w-full bg-amber-50 border border-amber-200/70 px-3 py-1.5 rounded-xl text-[11px] font-medium text-amber-900">
                      Instagram Paused · Mindful Check-in
                    </div>

                    <div className="my-auto flex flex-col items-center">
                      <MascotCharacter
                        mood="gentle_nudge"
                        size="md"
                        showSpeechBubble={false}
                      />
                      <h4 className="text-base font-bold text-stone-900 mt-2">Take a breath with Lumi</h4>
                      <p className="text-xs text-stone-500 mt-1 max-w-[220px]">
                        What is your heart looking for right now? Connection, rest, or just habit?
                      </p>

                      {/* 5-Second Mindful Breathing Circle */}
                      <div className="mt-4 relative flex items-center justify-center w-24 h-24">
                        <div className="absolute inset-0 rounded-full border-4 border-amber-200 animate-ping opacity-25" />
                        <div className="w-20 h-20 rounded-full bg-amber-100 border-2 border-amber-300 flex flex-col items-center justify-center text-amber-900">
                          <span className="text-lg font-bold font-mono">
                            {breathCountdown > 0 ? `${breathCountdown}s` : 'Ready'}
                          </span>
                          <span className="text-[9px] font-medium uppercase text-amber-700">
                            {breathCountdown > 0 ? 'Breathe' : 'Mindful'}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="w-full space-y-2 mt-4">
                      <button
                        onClick={() => handleScreenSwitch('dashboard')}
                        className="w-full py-2.5 bg-emerald-700 hover:bg-emerald-800 text-white rounded-xl text-xs font-semibold transition-colors cursor-pointer"
                      >
                        Put Down Phone (+5 Mindful Points)
                      </button>
                      <button
                        onClick={() => handleScreenSwitch('dashboard')}
                        className="w-full py-2 bg-stone-100 hover:bg-stone-200 text-stone-600 rounded-xl text-[11px] font-medium transition-colors cursor-pointer"
                      >
                        I really need to use it (Zero Guilt)
                      </button>
                    </div>
                  </div>
                )}

                {/* SCREEN 3: ZEN FOCUS MODE */}
                {activeScreen === 'focus' && (
                  <div className="flex flex-col items-center justify-between h-full py-2 text-center">
                    <div className="flex items-center justify-between w-full text-xs text-stone-500 px-1">
                      <span>Restful Screen Time</span>
                      <span className="flex items-center gap-1 text-emerald-700 font-medium">
                        <Wind className="w-3.5 h-3.5" /> Forest Rain
                      </span>
                    </div>

                    <div className="my-auto flex flex-col items-center">
                      <MascotCharacter
                        mood="zen_focus"
                        size="md"
                        showSpeechBubble={false}
                      />
                      <div className="text-3xl font-extrabold font-mono text-stone-900 mt-3 tracking-tight">
                        {formatTime(focusSeconds)}
                      </div>
                      <p className="text-xs text-stone-500 mt-1">Lumi is gently breathing with you</p>
                    </div>

                    <div className="w-full flex items-center gap-2">
                      <button
                        onClick={() => setIsFocusing(!isFocusing)}
                        className={`flex-1 py-3 rounded-2xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-all cursor-pointer ${
                          isFocusing ? 'bg-amber-100 text-amber-900' : 'bg-stone-900 text-white'
                        }`}
                      >
                        {isFocusing ? <Pause className="w-3.5 h-3.5" /> : <Play className="w-3.5 h-3.5 fill-white" />}
                        <span>{isFocusing ? 'Pause Breath' : 'Begin Focus'}</span>
                      </button>
                      <button
                        onClick={() => {
                          setIsFocusing(false);
                          setFocusSeconds(1500);
                        }}
                        className="p-3 bg-stone-100 hover:bg-stone-200 text-stone-600 rounded-2xl transition-colors cursor-pointer"
                        title="Reset Timer"
                      >
                        <RotateCcw className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                )}

                {/* SCREEN 4: MILESTONE JOY CELEBRATION */}
                {activeScreen === 'milestone' && (
                  <div className="flex flex-col items-center justify-between h-full py-2 text-center">
                    <div className="w-full bg-amber-50 border border-amber-200/70 px-3 py-1.5 rounded-xl text-[11px] font-semibold text-amber-900">
                      🏆 Milestone Unlocked!
                    </div>

                    <div className="my-auto flex flex-col items-center">
                      <MascotCharacter
                        mood="celebrating"
                        size="md"
                        showSpeechBubble={false}
                      />
                      <h4 className="text-base font-bold text-stone-900 mt-2">Mindful Blossom Master</h4>
                      <p className="text-xs text-stone-600 mt-1 max-w-[230px]">
                        You completed 5 continuous days of mindful screen control. Your digital garden is in full bloom!
                      </p>

                      <div className="mt-3 flex items-center gap-2 bg-emerald-50 px-3 py-1.5 rounded-full border border-emerald-200 text-emerald-800 text-xs font-semibold">
                        <Award className="w-4 h-4 text-emerald-600" />
                        <span>+50 Blossom Seeds Unlocked</span>
                      </div>
                    </div>

                    <button
                      onClick={triggerMilestoneConfetti}
                      className="w-full py-3 bg-emerald-700 hover:bg-emerald-800 text-white rounded-2xl text-xs font-semibold shadow-xs transition-transform active:scale-98 cursor-pointer"
                    >
                      Celebrate & Water Garden 🎉
                    </button>
                  </div>
                )}
              </div>

              {/* Bottom Mobile Tab Bar Navigation */}
              <div className="px-6 pt-2 border-t border-stone-200/60 grid grid-cols-4 gap-1 text-center">
                <button
                  onClick={() => handleScreenSwitch('dashboard')}
                  className={`flex flex-col items-center py-1 cursor-pointer ${
                    activeScreen === 'dashboard' ? 'text-emerald-700 font-bold' : 'text-stone-400'
                  }`}
                >
                  <Smile className="w-4 h-4" />
                  <span className="text-[9px] mt-0.5">Oasis</span>
                </button>
                <button
                  onClick={() => handleScreenSwitch('intercept')}
                  className={`flex flex-col items-center py-1 cursor-pointer ${
                    activeScreen === 'intercept' ? 'text-emerald-700 font-bold' : 'text-stone-400'
                  }`}
                >
                  <Shield className="w-4 h-4" />
                  <span className="text-[9px] mt-0.5">Friction</span>
                </button>
                <button
                  onClick={() => handleScreenSwitch('focus')}
                  className={`flex flex-col items-center py-1 cursor-pointer ${
                    activeScreen === 'focus' ? 'text-emerald-700 font-bold' : 'text-stone-400'
                  }`}
                >
                  <Clock className="w-4 h-4" />
                  <span className="text-[9px] mt-0.5">Focus</span>
                </button>
                <button
                  onClick={() => handleScreenSwitch('milestone')}
                  className={`flex flex-col items-center py-1 cursor-pointer ${
                    activeScreen === 'milestone' ? 'text-emerald-700 font-bold' : 'text-stone-400'
                  }`}
                >
                  <Award className="w-4 h-4" />
                  <span className="text-[9px] mt-0.5">Rewards</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Behavioral Explanation Column */}
        <div className="lg:col-span-6 space-y-5">
          <div className="bg-stone-50 p-6 rounded-3xl border border-stone-200/70">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-800">
              Why This Screen Pattern Works
            </span>
            <h3 className="text-xl font-bold text-stone-900 mt-1">
              {activeScreen === 'dashboard' && '1. The Daily Oasis: Welcoming, Not Monitoring'}
              {activeScreen === 'intercept' && '2. Mindful Friction: Autonomy Preserved'}
              {activeScreen === 'focus' && '3. Zen Focus: Parasympathetic Co-Regulation'}
              {activeScreen === 'milestone' && '4. Milestone Joy: Multisensory Dopamine'}
            </h3>

            <p className="text-sm text-stone-600 mt-2 leading-relaxed">
              {activeScreen === 'dashboard' &&
                'Traditional screen time apps treat users like inmates with strict prison bars and red warnings. Bloomly greets the user with Lumi in a warm botanical sanctuary, celebrating time lived in the real world rather than dwelling on screentime guilt.'}
              {activeScreen === 'intercept' &&
                'Hard lockouts spark immediate frustration and induce users to delete the app. Our 5-second mindful breath introduces healthy neurological friction. It invites awareness, gives the user full sovereignty to proceed without guilt, and turns an impulse into a conscious choice.'}
              {activeScreen === 'focus' &&
                'During deep work or screen detox sessions, Lumi breathes in synchrony with a 4s inhale and 4s exhale. This parasympathetic rhythm cues the vagus nerve, calming the anxiety that usually drives compulsive phone checking.'}
              {activeScreen === 'milestone' &&
                'Algorithmic social feeds rely on variable reward loops. When a user hits a detox milestone, Lumi unleashes uninhibited joy—jumping, throwing golden leaf confetti, and unlocking a tangible botanical evolution stage.'}
            </p>

            {/* Implementation checklist for agent */}
            <div className="mt-4 pt-4 border-t border-stone-200/80">
              <span className="text-xs font-semibold text-stone-800 block mb-2">Agent Implementation Directives:</span>
              <ul className="text-xs text-stone-600 space-y-1.5 list-disc pl-4">
                {activeScreen === 'dashboard' && (
                  <>
                    <li>Render Lumi with soft ambient floating keyframes (`animate-float`).</li>
                    <li>Avoid red progress bars; use gradient emerald `#4ADE80` to `#16A34A`.</li>
                    <li>Display positive framing: "1h 45m real life lived" instead of "Time wasted".</li>
                  </>
                )}
                {activeScreen === 'intercept' && (
                  <>
                    <li>Trigger when monitored package opens via Accessibility/UsageStats API.</li>
                    <li>Provide a 5-second non-blocking countdown with graceful bypass button.</li>
                    <li>Never lock emergency phone, messages, or calendar applications.</li>
                  </>
                )}
                {activeScreen === 'focus' && (
                  <>
                    <li>Keep screen awake using WakeLock API during active breathing.</li>
                    <li>Provide soothing white noise or rain ambient audio loop.</li>
                    <li>Store session minutes to local encrypted storage or Firestore.</li>
                  </>
                )}
                {activeScreen === 'milestone' && (
                  <>
                    <li>Trigger haptic feedback pattern: `[30, 60, 40]` ms pulse.</li>
                    <li>Spawn particle confetti using canvas-confetti or native Lottie.</li>
                    <li>Award 'Seedling Shield' preventing streak loss on busy days.</li>
                  </>
                )}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
