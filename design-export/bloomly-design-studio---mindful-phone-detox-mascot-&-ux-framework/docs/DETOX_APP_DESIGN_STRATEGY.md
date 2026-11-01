# BLOOMLY: Mindful Phone Detox App - Visual & Behavioral Design Framework
**Target Application**: Supportive Screen Time & Phone Addiction Controller Mobile App
**Mascot Guide**: "Lumi" the Sprout Spirit (Cloud-Seedling)
**Core Design Philosophy**: Compassionate Mindfulness, Positive Reinforcement, Zero-Shame Autonomy

---

## 1. Character Identity & Visual Anatomy: "Lumi"
Lumi is a gentle, glowing cloud-seedling creature that lives on the user's phone. Unlike traditional screen time apps that act as harsh digital prison wardens, Lumi acts as an affectionate, encouraging companion celebrating time spent in the real world.

### Physical Features
- **Silhouette**: Organic soft cloud-teardrop shape (no sharp corners, warm rounded radii).
- **Sprout on Head**: Dynamic green botanical leaf that acts as an emotional barometer:
  - Upright & swaying: Happy, curious, or energetic
  - Softly drooping / resting: Bedtime wind-down mode
  - Glowing & blooming: Task completed, streak milestone unlocked
- **Facial Expressions**:
  - Eyes: Big anime catchlights when celebrating (`wide_excited`), relaxed peaceful downward curves during mindful breathing (`closed_peaceful`), curious asymmetrical tilt on app open (`curious`).
  - Cheeks: Rosy pink oval blush with rhythmic opacity synchronized to breathing cycles.
  - Paws: Soft rounded marshmallow paws. Hands in air during celebration, holding a cozy mug and blanket during emergency bypass/relapse, holding a watering can during streak check-ins.
- **Ambient Aura**:
  - Sage Green (`#86EFAC`): Baseline idle calm
  - Golden Honey (`#FDE047`): Milestone victory & task completion
  - Soft Peach Amber (`#FDBA74`): Mindful friction pause (NEVER harsh red)
  - Lavender Dusk (`#DDD6FE`): Emergency bypass comfort & nighttime curfew

---

## 2. Mascot Emotion State Machine & Trigger Logic
Your application should track the following state model:

```typescript
export type MascotMood =
  | 'idle_happy'       // Default home screen state
  | 'zen_focus'        // Active 25m focus or breathing session
  | 'celebrating'      // User completed a screen-free block or daily goal
  | 'sleeping'         // Bedtime curfew active (e.g. 10:00 PM - 7:00 AM)
  | 'gentle_nudge'     // User opens restricted social media app
  | 'comforting'       // User breaks intentional limit or uses emergency bypass
  | 'watering_plant';  // Daily streak maintained, watering digital garden
```

### State Triggers & Responses Table

| Event / Trigger | Mascot Mood | Visual Action | Copy Script | Haptic Pattern |
| :--- | :--- | :--- | :--- | :--- |
| **User finishes focus session or daily limit** | `celebrating` | Leaps up, golden leaf confetti, big sparkly eyes | *"You did it! Today's goal is complete! Look at our garden blooming."* | `[30, 60, 40]ms` double heartbeat pulse |
| **User opens restricted app (e.g. Instagram)** | `gentle_nudge` | Curious head tilt, amber aura, 5s breath circle | *"Checking in with kindness: what is your heart hoping to find right now?"* | `15ms` gentle tick |
| **User uses Emergency Bypass** | `comforting` | Snuggles in knit blanket, warm heart mug, lavender glow | *"Life happens, and that is 100% okay! We are learning together. No guilt here."* | `40ms` soft comfort pulse |
| **Active 25m Focus Session** | `zen_focus` | Sits cross-legged, eyes softly closed, slow 4s chest breath | *"We are resting our minds together. Breathe in deeply... breathe out slowly."* | `60ms` calm wave pulse |
| **Bedtime curfew (e.g. 10:00 PM)** | `sleeping` | Nightcap on, floating gently, floating 'Zzz' particles | *"Shh... stars are out. It's time to rest your eyes and recharge your spirit."* | `120ms` fade-out soothing wave |
| **Daily Streak Check-in** | `watering_plant` | Waters mini sprout, new dewy leaf pops out | *"Day {streak} of intentional living! Ready to water our seedling?"* | `[10, 10]ms` double light tick |

---

## 3. UI Color Palette & Design Tokens

### Living Botanicals (Primary & Calming)
- `Sprout Meadow`: `#15803D` (Primary buttons, growth rings, active indicators)
- `Gentle Sage`: `#86EFAC` (Breathing ring aura, tags, positive highlights)
- `Morning Mint`: `#DCFCE7` (Session cards, light container backgrounds)
- `Forest Canopy`: `#14532D` (High-contrast typography)

### Warm Linen & Earth (Anti-Eye Strain Canvas)
- `Warm Oat Canvas`: `#FAF8F5` (App background - soft on retinas)
- `Ceramic Cream`: `#F5EFEB` (Card surface background)
- `Sandstone Border`: `#E7DFD5` (1px hairline borders)
- `Warm Charcoal`: `#292524` (Body typography, readable without glare)
- `River Pebble`: `#78716C` (Secondary unboxed metadata)

### Anti-Panic Alerts (Compassionate Intervention)
- `Peach Bloom`: `#FDBA74` (Mindful friction pause - NEVER use alarmist red)
- `Apricot Warmth`: `#FFEDD5` (5-second breathing scrim background)
- `Lavender Dusk`: `#DDD6FE` (Comfort state, zero-shame bypass shield)
- `Golden Honey`: `#FDE047` (Celebration stars, badge unlocks)

---

## 4. Auditory Soundscape Design Tokens (Anti-Casino Audio)
Traditional mobile apps use high-pitched, sharp casino-like chime sweeps designed to trigger compulsive dopamine loops. Bloomly replaces this with organic, parasympathetic acoustic frequencies:

| Soundscape Token | Musical Key / Frequency | Trigger Event | Psychoacoustic Function | File Asset Spec |
| :--- | :--- | :--- | :--- | :--- |
| **Golden Solfeggio Bell** | 528 Hz (C5 Solfeggio) | User finishes daily goal or major detox milestone | Stimulates vagus nerve calm and profound accomplishment | `snd_lumi_celebrate_528hz.wav` (48kHz, 24-bit PCM, volume peak -3dB) |
| **Bamboo Kalimba Arpeggio** | C Major Pentatonic (C5, E5, G5, A5) | Checking off an offline mindful task (e.g. 15m walk) | Organic wooden timbre grounds user in the physical world | `snd_lumi_kalimba_sparkle.wav` (70ms arpeggio interval) |
| **Tibetan Singing Bowl Hum** | 216 Hz with 4.5 Hz Theta pulse | Bedtime wind-down mode or entering Zen focus | Induces alpha-to-theta brainwave relaxation | `snd_lumi_singing_bowl_hum.wav` (3.5s smooth resonance) |
| **Dewdrop Water Pluck** | Frequency glide (880 Hz → 660 Hz) | Tapping Lumi to pet, or completing 1 breath cycle | Light, playful water acoustic indicating gentle presence | `snd_lumi_dewdrop.wav` (0.35s instant attack) |
| **Misty Forest Wind Chime** | Silver Cascade (E5, G#5, B5, E6) | Multi-day streak unlocked or garden evolution | Wonder and gentle organic flourishing | `snd_lumi_wind_chime_cascade.wav` (1.5s airy shimmer) |

---

## 5. Typography Hierarchy
- **Display Face**: `Outfit` (Geometric, friendly rounded terminals, warm authority)
- **Body Face**: `Plus Jakarta Sans` (Humanist sans, highly legible at small mobile sizes)
- **Timer & Metrics**: `JetBrains Mono` (Tabular figures to prevent layout jitter during live counting)

---

## 5. Supportive vs. Restrictive UX Rules

### Rule 1: Mindful Friction Over Hard Lockouts
- **Problem**: Harsh lockouts cause psychological reactance. Users get angry, feel trapped, and delete the app.
- **Solution**: When user opens an app, show a **5-second Mindful Breathing Screen**. Lumi breathes with the user. After 5 seconds, provide two non-judgmental buttons:
  1. *"Put Down Phone (+5 Mindful Points)"*
  2. *"I really need to use it (Zero Guilt)"*

### Rule 2: Seedling Shields Over Broken Streaks
- **Problem**: When a user misses one day and loses a 30-day streak, the "what-the-hell" effect triggers a massive relapse binge.
- **Solution**: Award users 2 automatic **"Seedling Shields"** per week. If they exceed their limit on a hectic day, Lumi wraps in a blanket: *"Lumi protected your garden today! Rest up, we continue tomorrow."*

### Rule 3: Multisensory Celebrations
- When a task or daily goal is completed:
  1. Trigger canvas-confetti with soft pastels (`#4ADE80`, `#FDE047`, `#F472B6`).
  2. Play a gentle soft pentatonic chime sound.
  3. Emit a double heartbeat haptic vibration (`30ms`, gap `60ms`, `40ms`).
  4. Animate the digital seedling adding a new leaf.

---

## 6. Tone of Voice & Copywriting Directives
- **Banned Words**: "Failed", "Blocked", "Banned", "Addict", "Guilty", "Warning", "Violated limit", "Disappointing", "Shame", "Punishment".
- **Recommended Phrases**: "Notice with kindness", "Let's take a breath together", "Your real life is waiting outside", "Every step counts", "Proud of your awareness", "Resting our minds", "Our garden is growing", "You are in control".
