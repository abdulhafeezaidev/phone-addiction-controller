---
name: One Core Dark
colors:
  surface: '#121414'
  surface-dim: '#121414'
  surface-bright: '#383939'
  surface-container-lowest: '#0d0e0f'
  surface-container-low: '#1a1c1c'
  surface-container: '#1e2020'
  surface-container-high: '#292a2a'
  surface-container-highest: '#343535'
  on-surface: '#e3e2e2'
  on-surface-variant: '#c6c5d5'
  inverse-surface: '#e3e2e2'
  inverse-on-surface: '#2f3131'
  outline: '#908f9e'
  outline-variant: '#454652'
  surface-tint: '#bdc2ff'
  primary: '#bdc2ff'
  on-primary: '#121f8b'
  primary-container: '#5e6ad2'
  on-primary-container: '#fdfaff'
  inverse-primary: '#4854bb'
  secondary: '#c8c6c8'
  on-secondary: '#303032'
  secondary-container: '#474649'
  on-secondary-container: '#b6b4b7'
  tertiary: '#ffb867'
  on-tertiary: '#482900'
  tertiary-container: '#a56500'
  on-tertiary-container: '#fffaf8'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dfe0ff'
  primary-fixed-dim: '#bdc2ff'
  on-primary-fixed: '#000965'
  on-primary-fixed-variant: '#2e3aa2'
  secondary-fixed: '#e4e2e4'
  secondary-fixed-dim: '#c8c6c8'
  on-secondary-fixed: '#1b1b1d'
  on-secondary-fixed-variant: '#474649'
  tertiary-fixed: '#ffddbb'
  tertiary-fixed-dim: '#ffb867'
  on-tertiary-fixed: '#2b1700'
  on-tertiary-fixed-variant: '#673d00'
  background: '#121414'
  on-background: '#e3e2e2'
  surface-variant: '#343535'
typography:
  display-lg:
    fontFamily: Hanken Grotesk
    fontSize: 56px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.02em
  headline-xl:
    fontFamily: Hanken Grotesk
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 44px
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  viewing-area-top: 80px
  interaction-margin: 24px
  gutter: 16px
  card-padding: 20px
  stack-gap: 12px
---

## Brand & Style

This design system is a high-fidelity adaptation of the **Samsung One UI 6.0** philosophy, optimized for dark mode environments. It prioritizes **reachability** and **ergonomics** through a strict "Viewing Area" and "Interaction Area" split.

The aesthetic is **Corporate / Modern** with a focus on systematic utility. It evokes a sense of professional reliability and calm through its charcoal base and deep indigo accents. The UI avoids unnecessary ornamentation, relying on purposeful grouping, subtle squircular geometry, and high-quality typography to guide the user's eye.

**Key Principles:**
- **Reachability First:** Content is pushed to the bottom 2/3 of the screen for comfortable thumb access.
- **Visual Hierarchy:** Large, bold headers define the viewing area, while interactive elements inhabit the lower containers.
- **Intentional Depth:** Depth is created through tonal layering rather than aggressive shadows.

## Colors

The palette is rooted in a near-black charcoal to minimize eye strain and maximize OLED efficiency. 

- **Primary (Indigo):** Used exclusively for actionable states, toggles, and progress indicators. 
- **Surfaces:** A three-tier grey system is used to define hierarchy. 
  - `Background`: #121214 (Purest dark)
  - `Surface-Container`: #212123 (Used for squircular cards)
  - `Surface-Variant`: #2C2C2E (Used for active states or nested elements)
- **Status:** Standard semantic colors apply but are muted to match the dark theme: Success (Emerald), Warning (Amber), Error (Rose).

## Typography

This design system uses **Hanken Grotesk** for its clean, geometric, and professional feel that mirrors the modern One UI aesthetic.

**Hierarchy Rules:**
- **Viewing Area Titles:** Use `headline-xl` or `display-lg`. These should have significant top padding (up to 25% of screen height) to ensure the content below falls within the reachability zone.
- **Card Titles:** Use `title-md` for primary card labels.
- **Information Labels:** Use `label-md` for secondary metadata inside cards, often with a reduced opacity (60-70%).

## Layout & Spacing

The layout follows a **fluid grid** model with a heavy emphasis on vertical zoning.

- **The 1/3 - 2/3 Rule:** On mobile, the top third of the screen is reserved for large titles and "Viewing" (non-interactive) status info. The bottom two-thirds is the "Interaction Area."
- **Safe Margins:** A consistent 24px horizontal margin is applied to all main containers.
- **Card-Based Grid:** Content is organized into cards. On mobile, cards span the full width minus margins. On tablet/desktop, cards use a 12-column grid, often spanning 4 or 6 columns.
- **Density:** Spacing between cards (`stack-gap`) is kept tight (12px) to maintain a cohesive "system" feel.

## Elevation & Depth

Hierarchy is established through **Tonal Layers** rather than heavy shadows.

- **Background:** The base layer (#121214).
- **Cards:** Elevated once using color (#212123). Cards use a very thin (1px) border of #2C2C2E to define edges against the dark background.
- **Shadows:** Only used on high-level floating elements (like Bottom Sheets or Dialogs). These are "Soft Shadows"—very diffused (20px-40px blur), low opacity (15%), and tinted with the primary indigo color.
- **Active State:** When a card or item is pressed, it shifts to #2C2C2E.

## Shapes

The design system utilizes the **Samsung Squircle** as its primary geometric signature.

- **Cards:** Use `rounded-xl` (24px on mobile) to create a soft but professional container.
- **Buttons:** Large buttons use `rounded-lg` (16px) for a modern look that isn't fully pill-shaped.
- **Toggles:** Only the internal toggle "nub" is a true circle; the track follows the squircle language.
- **Selection Indicators:** Bottom navigation active states use a squircular background highlight (pill-like but with slightly flatter sides).

## Components

### Buttons
- **Primary:** Solid indigo (#5E6AD2) with white text. Squircular corners.
- **Secondary:** Tonal grey (#2C2C2E) with white text.
- **Sizes:** Large (56px height) for main actions; Small (36px height) for secondary card actions.

### Cards
- Squircular containers with 20px internal padding.
- Used to group related information (e.g., stats, settings, list items).
- Background: #212123.

### Toggles & Controls
- **Toggle:** Track is grey when off, Indigo when on. The knob is always white (#FFFFFF).
- **Checkboxes:** Squircular (not square) with a 4px corner radius. Indigo fill when checked.

### Bottom Navigation
- Minimalist icons (outlined, 2px stroke).
- The active state is indicated by a subtle indigo squircular pill behind the icon and indigo text.

### Input Fields
- Filled style: #212123 background with a 1px bottom border that turns Indigo on focus.
- Placeholder text: #9E9E9E.