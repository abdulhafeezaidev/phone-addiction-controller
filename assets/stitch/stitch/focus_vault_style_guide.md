# Focus Vault | Style Guide & Design Specification
**Design System:** Samsung One UI 6.0 Optimized
**Target Device:** Samsung Galaxy A52s 5G (Mobile)

## 1. Visual Identity
Focus Vault uses a professional, high-contrast "Dark Mode" aesthetic designed for utility, focus, and reachability.

### Color Palette
*   **Surface:** `#121414` (Deep Charcoal) - Primary background for screens and containers.
*   **Primary:** `#5E6AD2` (Indigo) - Main action color, used for primary buttons, active states, and highlights.
*   **On-Surface:** `#FFFFFF` (Pure White) - Primary text and icons for maximum readability.
*   **Surface-Variant:** `#1A1C1C` - Subtle secondary background for cards and nested elements.
*   **Error/Danger:** `#CF6679` - Used for "Emergency Exit" and "Danger Zone" actions.

## 2. Typography
**Typeface:** Hanken Grotesk
*   **Display / Large Headers:** 32pt - 48pt, Medium weight. Used in the "Viewing Area" at the top of screens.
*   **Card Headlines:** 18pt, Semi-bold.
*   **Body Copy:** 14pt - 16pt, Regular weight.
*   **Labels/Captions:** 12pt, Regular.

## 3. One UI 6.0 Layout Principles
*   **Viewing Area (Top 1/3):** Large screen titles and summary status indicators. This area is for information consumption.
*   **Interaction Area (Bottom 2/3):** All buttons, toggles, and navigation elements are placed here for easy thumb reachability.
*   **Container Corner Radius:** 24px (standard) or 32px (large containers).
*   **Gutter / Margins:** 20px standard side padding.

## 4. Key Components
### Cards
Standard One UI style with a `#1A1C1C` background, 24px corner radius, and subtle 1px border for definition.

### Primary Buttons
Indigo background (`#5E6AD2`), rounded-full (pill shape), with white semi-bold text.

### Navigation
Bottom navigation bar with 5 destinations (Home, Apps, Focus, Stats, Settings). Active states use an indigo background capsule.

## 5. Screen Inventory
1.  **Home Dashboard**: Central hub with inactivity status and weekly trends.
2.  **Active Focus**: Countdown timer with session-specific controls.
3.  **Focus Stats**: Detailed data visualization and "Time Saved" metrics.
4.  **Application Settings**: Theme toggles and general configuration.
5.  **System Permissions**: OS-level service diagnostic flow.
6.  **Administrator Settings**: Security and PIN management.
7.  **App Blocked Overlay**: Full-screen restrictive interface.
8.  **Setup Wizard**: Multi-step onboarding with trust-building explainers.