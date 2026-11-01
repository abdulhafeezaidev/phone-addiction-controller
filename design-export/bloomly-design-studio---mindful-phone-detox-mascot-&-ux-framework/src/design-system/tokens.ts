export interface ColorToken {
  name: string;
  hex: string;
  role: string;
  description: string;
  textColor: string;
}

export interface ColorFamily {
  family: string;
  description: string;
  tokens: ColorToken[];
}

export const DESIGN_TOKENS = {
  appName: "Bloomly",
  tagline: "Your gentle, mindful companion for calmer screen habits",
  mascotName: "Lumi",
  mascotSpecies: "Sprout Spirit (Cloud-Seedling)",
  
  palettes: [
    {
      family: "Living Botanicals (Primary & Calming)",
      description: "Organic, grounded greens that stimulate parasympathetic nervous calm instead of dopamine urgency.",
      tokens: [
        { name: "Sprout Meadow", hex: "#15803D", role: "Primary Active & Growth", description: "Primary brand color, milestone badges, positive feedback rings", textColor: "#FFFFFF" },
        { name: "Gentle Sage", hex: "#86EFAC", role: "Soft Backgrounds & Accents", description: "Breathing guide aura, completed session tags, active tabs", textColor: "#14532D" },
        { name: "Morning Mint", hex: "#DCFCE7", role: "Surface Highlight", description: "Card backgrounds for active focus, success toasts", textColor: "#166534" },
        { name: "Forest Canopy", hex: "#14532D", role: "Deep Text & Headers", description: "High contrast accessible typography on sage backgrounds", textColor: "#FFFFFF" },
      ],
    },
    {
      family: "Warm Linen & Earth (Anti-Eye Strain Canvas)",
      description: "Warm neutral tones mimicking natural paper and ceramics, eliminating cold clinical glare.",
      tokens: [
        { name: "Warm Oat Canvas", hex: "#FAF8F5", role: "App Background", description: "Base canvas color for light mode, soft on eyes during morning & evening", textColor: "#292524" },
        { name: "Ceramic Cream", hex: "#F5EFEB", role: "Card Surface", description: "Container card background with single-elevation depth", textColor: "#292524" },
        { name: "Sandstone Border", hex: "#E7DFD5", role: "Subtle Hairlines", description: "1px border separators replacing harsh dark lines", textColor: "#44403C" },
        { name: "Warm Charcoal", hex: "#292524", role: "Primary Body Typography", description: "Warm black that maintains 10:1 contrast without retina harshness", textColor: "#FAF8F5" },
        { name: "River Pebble", hex: "#78716C", role: "Secondary Typography", description: "Unboxed metadata, session time counts, helper copy", textColor: "#FFFFFF" },
      ],
    },
    {
      family: "Mindful Intervention & Compassion (Anti-Panic Alerts)",
      description: "Crucial for detox apps: NEVER use punitive bright red alarms that trigger shame or rebellious app bypass.",
      tokens: [
        { name: "Peach Bloom", hex: "#FDBA74", role: "Mindful Friction / Nudge", description: "Soft amber peach when user attempts opening a restricted app", textColor: "#7C2D12" },
        { name: "Apricot Warmth", hex: "#FFEDD5", role: "Intervention Scrim", description: "Gentle overlay background during the 5-second breathing pause", textColor: "#9A3412" },
        { name: "Lavender Dusk", hex: "#DDD6FE", role: "Evening Curfew & Comfort", description: "Zero-shame bypass shield, winding down mode, compassion state", textColor: "#4C1D95" },
        { name: "Starlight Lilac", hex: "#F3E8FF", role: "Night Mode Accent", description: "Soft glow when night screen limit is active", textColor: "#581C87" },
        { name: "Golden Honey", hex: "#FDE047", role: "Milestone Celebration", description: "Joyful celebratory bursts, badge unlock, streak star aura", textColor: "#713F12" },
      ],
    },
  ] as ColorFamily[],

  typography: {
    displayFont: "Outfit (Geometric, warm rounded terminals, friendly approachable authority)",
    bodyFont: "Plus Jakarta Sans (Crisp, warm neutral humanist sans, highly legible at small sizes)",
    monoFont: "JetBrains Mono (Tabular numerals for timers, focus minutes, and clock faces)",
    hierarchy: [
      { level: "Hero Display", size: "32px / 2rem", weight: "700 Bold", useCase: "Milestone celebration headers, big motivational anchors" },
      { level: "Page Title", size: "22px / 1.375rem", weight: "600 SemiBold", useCase: "Top bar headers, screen titles, dialog headlines" },
      { level: "Card Headline", size: "17px / 1.0625rem", weight: "600 SemiBold", useCase: "Widget cards, habit blocks, dialogue bubble lead" },
      { level: "Body Text", size: "15px / 0.9375rem", weight: "400 Regular", useCase: "Mascot speech copy, reflective guidance, task descriptions" },
      { level: "Metadata & Timers", size: "13px / 0.8125rem", weight: "500 Medium", useCase: "Unboxed time counts, streak counts, progress labels" },
    ],
  },

  animationChoreography: [
    {
      name: "The Parasympathetic Breath",
      duration: "4000ms loop",
      easing: "cubic-bezier(0.4, 0, 0.2, 1)",
      description: "Mascot smoothly expands by 8% over 4s on inhale, holds for 1s, and contracts over 4s on exhale. Visual guide for user heart rate reduction.",
    },
    {
      name: "Celebratory Spring Burst",
      duration: "600ms",
      easing: "spring(stiffness: 300, damping: 15)",
      description: "When task is checked off, mascot leaps upward 14px with elastic squash-and-stretch, showering soft leaf confetti and golden stars.",
    },
    {
      name: "Gentle Head Tilt (Nudge)",
      duration: "350ms",
      easing: "cubic-bezier(0.16, 1, 0.3, 1)",
      description: "Curious 6° head tilt when user opens a distracting app. Looks attentive and caring, never menacing or judgmental.",
    },
    {
      name: "Snuggle & Embrace (Compassion)",
      duration: "800ms",
      easing: "ease-in-out",
      description: "Used when user breaks limit or clicks emergency bypass. Mascot curls in cozy blanket, glowing lavender to dissolve guilt.",
    },
  ],

  haptics: [
    { type: "Light Taptic Tick", timing: "10ms", trigger: "Tapping mindful breathing circle or switching tabs" },
    { type: "Double Heartbeat Pulse", timing: "30ms - 60ms gap - 40ms", trigger: "Completing a detox task or reaching daily goal" },
    { type: "Soothing Slow Wave", timing: "120ms fade-out vibration", trigger: "Transitioning phone into Bedtime Sleep Curfew" },
  ],
};
