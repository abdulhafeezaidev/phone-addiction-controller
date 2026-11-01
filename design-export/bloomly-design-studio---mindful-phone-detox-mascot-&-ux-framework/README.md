# Bloomly

Bloomly is a compassionate, mobile-first screen-habit companion built around mindful friction, restorative focus sessions, Lumi the sprout spirit, and shame-free progress.

## Run locally

Install dependencies with Bun, then start the Vite development server:

```sh
bun install
bun run dev
```

Use `bun run lint` to type-check and `bun run build` to create a production build.

## Included

- Daily oasis dashboard with a configurable screen-time allowance and persistent local progress
- Five-second mindful pause preview with a free choice to put the phone down or continue
- Resumable focus timer with optional procedural ambient soundscapes
- Opt-in spoken Lumi messages using the device/browser's English speech synthesis voice
- Seedling Shields, weekly renewal, progress milestones, haptics, and soft celebrations
- Interactive SVG Lumi with all seven emotional states

The app's shared theme uses the strategy's botanical, warm-neutral, peach, lavender, and honey tokens across each screen. Spoken Lumi is optional, uses the device's available speech voice (so the exact voice varies by browser/device), and can be turned on or off from the header.

This browser app demonstrates the app-open pause flow; detecting launches of other apps or reading device screen-time requires native Android/iOS permissions and platform integration. Progress and the voice preference are stored in this browser on this device.
