export interface UXPatternComparison {
  scenario: string;
  traditionalRestrictive: {
    approach: string;
    psychologicalImpact: string;
    mascotReaction: string;
  };
  bloomlySupportive: {
    approach: string;
    psychologicalImpact: string;
    mascotReaction: string;
    implementationGuideline: string;
  };
}

export const SUPPORTIVE_UX_PATTERNS: UXPatternComparison[] = [
  {
    scenario: "User reaches app time limit (e.g., 30 mins on Instagram)",
    traditionalRestrictive: {
      approach: "Hard lockout with full-screen dark overlay: 'You are blocked. Come back tomorrow.'",
      psychologicalImpact: "Triggers psychological reactance, frustration, anxiety, and urges users to delete or disable the blocker.",
      mascotReaction: "Angry mascot, locked padlock, red stop signs.",
    },
    bloomlySupportive: {
      approach: "Mindful 5-second Breathing Friction: Lumi gently steps in: 'You’ve reached your mindful limit for Instagram today. Let’s take 1 deep breath together. Still need it? Tap below.'",
      psychologicalImpact: "Breaks autopilot unconscious scrolling without stripping autonomy. User feels in control of their choices.",
      mascotReaction: "Curious, warm expression. Sprout leaf sways gently. Offers 1-tap 'Give me 5 more minutes for emergency' with zero guilt penalty.",
      implementationGuideline: "Render an accessible modal with a 5-second breathing ring. Allow an intentional 'Continue Mindfully' button after the breath completes.",
    },
  },
  {
    scenario: "User breaks a screen-free streak or uses emergency bypass",
    traditionalRestrictive: {
      approach: "Broken streak alert: 'STREAK LOST! Day 0. You failed your goal.'",
      psychologicalImpact: "The 'What-the-hell' effect: users feel shame, declare failure, and binge phone usage even harder.",
      mascotReaction: "Sad, crying, or disappointed mascot looking at user.",
    },
    bloomlySupportive: {
      approach: "Seedling Shield & Compassion Reset: 'Life has busy days! Lumi protected your garden today with a Seedling Shield. Every moment you noticed your screen is progress.'",
      psychologicalImpact: "Self-compassion maintains motivation. Habits form through resilience, not uninterrupted perfection.",
      mascotReaction: "Snuggled with a warm mug and cozy blanket. Gives warm heart glow. Words: 'I'm still right here with you.'",
      implementationGuideline: "Provide 2 automatic streak shields per week. Frame bypasses as conscious choices rather than failures.",
    },
  },
  {
    scenario: "Completing a detox task (e.g. 25 min phone-free walk or focus)",
    traditionalRestrictive: {
      approach: "Generic checkbox or silent increment of minutes in an analytics chart.",
      psychologicalImpact: "Low dopamine payoff compared to the vibrant addictive apps the user just avoided.",
      mascotReaction: "Static icon or nothing.",
    },
    bloomlySupportive: {
      approach: "Multisensory Joy & Garden Bloom: Lumi leaps into the air with confetti, the seedling grows fresh dewy leaves, and the phone gives a warm double-pulse haptic tap.",
      psychologicalImpact: "Provides intrinsic organic reward that rivals algorithmic dopamine hits, associating offline presence with deep joy.",
      mascotReaction: "Jumping cheer animation, stars spinning, eyes curving in sheer happiness. Copy: 'Look at you flourish in the real world!'",
      implementationGuideline: "Trigger particle confetti (leaves & stars), play gentle soft pentatonic chime, animate seedling bloom stage.",
    },
  },
  {
    scenario: "Evening bedtime curfew approaching (e.g. 10:00 PM)",
    traditionalRestrictive: {
      approach: "Sudden harsh grayscale or screen shutdown warning alert.",
      psychologicalImpact: "User rushes to beat the clock, sparking late-night cortisol spike.",
      mascotReaction: "Clock countdown with red blinking border.",
    },
    bloomlySupportive: {
      approach: "Starlight Wind-Down: Background shifts to cozy twilight lavender, Lumi puts on a tiny sleeping nightcap and yawns softly, inviting user to pillow time.",
      psychologicalImpact: "Invites sleepy relaxation and parasympathetic rest instead of fight-or-flight confrontation.",
      mascotReaction: "Curled up softly sleeping, floating gently like a cloud, breathing quietly with soft 'Zzz' particles.",
      implementationGuideline: "Warm color temperature scrim, dim UI brightness 15%, soft ambient audio option (crickets/rain).",
    },
  },
  {
    scenario: "User picks up phone out of nervous fidget habit",
    traditionalRestrictive: {
      approach: "Notification banner: 'You picked up your phone 48 times today! Reduce usage.'",
      psychologicalImpact: "Scolding surveillance tone creates anxiety.",
      mascotReaction: "Disapproving face or warning triangle.",
    },
    bloomlySupportive: {
      approach: "Pocket Zen Pebble Widget: Quick lock-screen widget where tapping Lumi gives a soothing haptic breath cycle instead of opening social apps.",
      psychologicalImpact: "Substitutes the fidget impulse with a grounding mindfulness micro-habit.",
      mascotReaction: "Smiles and gently breathes in sync with user's thumb press.",
      implementationGuideline: "Provide iOS/Android interactive lock screen widget with 10-second breath guide.",
    },
  },
];

export const TONE_OF_VOICE_RULES = {
  philosophy: "Supportive Parent / Loving Best Friend (Non-Judgmental, Encouraging, Playful)",
  bannedWords: [
    "Failed", "Blocked", "Banned", "Addict", "Guilty", "Warning", "Violated limit", "Disappointing", "Shame", "Punishment"
  ],
  recommendedPhrases: [
    "Notice with kindness",
    "Let's take a breath together",
    "Your real life is waiting outside",
    "Every step counts",
    "Proud of your awareness",
    "Resting our minds",
    "Our garden is growing",
    "You are in control"
  ],
};
