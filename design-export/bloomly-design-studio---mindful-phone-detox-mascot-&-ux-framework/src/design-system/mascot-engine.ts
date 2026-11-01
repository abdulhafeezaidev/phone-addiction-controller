export type MascotMood =
  | 'idle_happy'
  | 'zen_focus'
  | 'celebrating'
  | 'sleeping'
  | 'gentle_nudge'
  | 'comforting'
  | 'watering_plant';

export interface MascotContext {
  activeSession: boolean;
  timeOfDay: 'morning' | 'afternoon' | 'evening' | 'night';
  minutesFocusedToday: number;
  dailyGoalMinutes: number;
  currentStreakDays: number;
  lastAction: 'started_focus' | 'completed_task' | 'unlocked_screen' | 'paused' | 'milestone_unlocked' | 'bypass_used';
}

export interface MascotResponse {
  mood: MascotMood;
  speechText: string;
  subtext: string;
  expression: {
    eyes: 'open_happy' | 'closed_peaceful' | 'wide_excited' | 'sleepy' | 'curious' | 'loving';
    mouth: 'smile' | 'open_joy' | 'neutral_gentle' | 'tiny_o';
    blush: boolean;
    auraColor: string;
  };
  animationVariant: 'bounce' | 'float' | 'breathe' | 'sparkle' | 'nod' | 'snuggle';
  hapticFeedback: 'gentle_tick' | 'success_pulse' | 'soft_double' | 'calm_wave';
}

/**
 * Resolves the mascot's emotional reaction and supportive message
 * based on user behavior and detox milestones.
 * Core philosophy: Positive reinforcement, zero shame, compassionate presence.
 */
export function resolveMascotState(context: MascotContext): MascotResponse {
  const { activeSession, timeOfDay, minutesFocusedToday, dailyGoalMinutes, currentStreakDays, lastAction } = context;

  // 1. Celebrating Milestone / Task Completion
  if (lastAction === 'completed_task' || lastAction === 'milestone_unlocked') {
    const isGoalMet = minutesFocusedToday >= dailyGoalMinutes;
    return {
      mood: 'celebrating',
      speechText: isGoalMet
        ? `You did it! Today's goal is complete! Look at how bright our garden is blooming.`
        : `Wonderful job! Another moment of your real life reclaimed. I'm so proud of you!`,
      subtext: `+20 Sprout Seeds earned for mindful presence`,
      expression: {
        eyes: 'wide_excited',
        mouth: 'open_joy',
        blush: true,
        auraColor: '#FDE047', // warm golden cheer
      },
      animationVariant: 'sparkle',
      hapticFeedback: 'success_pulse',
    };
  }

  // 2. Active Focus / Detox Session
  if (activeSession) {
    return {
      mood: 'zen_focus',
      speechText: `We are resting our minds together. Breathe in deeply... breathe out slowly.`,
      subtext: `Device notifications silenced · Lumi is keeping you company`,
      expression: {
        eyes: 'closed_peaceful',
        mouth: 'neutral_gentle',
        blush: true,
        auraColor: '#86EFAC', // peaceful sage
      },
      animationVariant: 'breathe',
      hapticFeedback: 'calm_wave',
    };
  }

  // 3. User Opened Screen / Gentle Friction Intercept
  if (lastAction === 'unlocked_screen') {
    return {
      mood: 'gentle_nudge',
      speechText: `Hey friend! Checking in with kindness: what are you hoping to find right now?`,
      subtext: `Take a 5-second breath before proceeding, or continue whenever you're ready.`,
      expression: {
        eyes: 'curious',
        mouth: 'tiny_o',
        blush: true,
        auraColor: '#FDBA74', // warm soft amber (never red)
      },
      animationVariant: 'nod',
      hapticFeedback: 'gentle_tick',
    };
  }

  // 4. Emergency Bypass / Relapse (Supportive, non-judgmental response)
  if (lastAction === 'bypass_used') {
    return {
      mood: 'comforting',
      speechText: `Life happens, and that is 100% okay! We are learning our rhythm. No guilt here.`,
      subtext: `Your streak is safe with Lumi's gentle shield. Take what you need.`,
      expression: {
        eyes: 'loving',
        mouth: 'smile',
        blush: true,
        auraColor: '#C4B5FD', // soothing lavender
      },
      animationVariant: 'snuggle',
      hapticFeedback: 'soft_double',
    };
  }

  // 5. Nighttime Curfew / Sleep Mode
  if (timeOfDay === 'night') {
    return {
      mood: 'sleeping',
      speechText: `Shh... stars are out. It's time to let your eyes rest and recharge your spirit.`,
      subtext: `Night wind down active · Blue light filter recommended`,
      expression: {
        eyes: 'sleepy',
        mouth: 'neutral_gentle',
        blush: true,
        auraColor: '#93C5FD', // soft night sky blue
      },
      animationVariant: 'float',
      hapticFeedback: 'calm_wave',
    };
  }

  // 6. Streak Watering / Daily Growth
  if (currentStreakDays > 0 && lastAction === 'started_focus') {
    return {
      mood: 'watering_plant',
      speechText: `Day ${currentStreakDays} of intentional living! Ready to water our mindful seedling?`,
      subtext: `Every screen-free minute helps your digital garden blossom`,
      expression: {
        eyes: 'open_happy',
        mouth: 'smile',
        blush: true,
        auraColor: '#6EE7B7', // emerald mint
      },
      animationVariant: 'bounce',
      hapticFeedback: 'gentle_tick',
    };
  }

  // 7. Default Idle Happy
  return {
    mood: 'idle_happy',
    speechText: `Hello! I'm Lumi, your pocket guide to calmer tech habits. How can I support you today?`,
    subtext: `Choose a mindful break, set an intentional limit, or just take a breath.`,
    expression: {
      eyes: 'open_happy',
      mouth: 'smile',
      blush: true,
      auraColor: '#A7F3D0',
    },
    animationVariant: 'float',
    hapticFeedback: 'gentle_tick',
  };
}

/**
 * Calculates progress and garden bloom tier
 */
export function calculateGardenProgress(minutesFocused: number, targetMinutes: number): {
  percentage: number;
  stageName: string;
  leavesCount: number;
  bloomState: 'seed' | 'sprout' | 'bud' | 'full_bloom';
} {
  const percentage = Math.min(100, Math.round((minutesFocused / Math.max(1, targetMinutes)) * 100));
  if (percentage >= 100) {
    return { percentage, stageName: 'Golden Blossom in Full Bloom', leavesCount: 6, bloomState: 'full_bloom' };
  }
  if (percentage >= 60) {
    return { percentage, stageName: 'Budding Flower', leavesCount: 4, bloomState: 'bud' };
  }
  if (percentage >= 25) {
    return { percentage, stageName: 'Young Green Sprout', leavesCount: 2, bloomState: 'sprout' };
  }
  return { percentage, stageName: 'Resting Seedling', leavesCount: 1, bloomState: 'seed' };
}
