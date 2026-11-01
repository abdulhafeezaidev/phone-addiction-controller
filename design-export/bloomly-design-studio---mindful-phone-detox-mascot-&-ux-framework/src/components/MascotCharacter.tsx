import React from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { MascotMood } from '../design-system/mascot-engine';

interface MascotCharacterProps {
  mood: MascotMood;
  size?: 'sm' | 'md' | 'lg' | 'hero';
  showSpeechBubble?: boolean;
  speechText?: string;
  subtext?: string;
  isInteractive?: boolean;
  onPet?: () => void;
}

export const MascotCharacter: React.FC<MascotCharacterProps> = ({
  mood,
  size = 'md',
  showSpeechBubble = true,
  speechText,
  subtext,
  isInteractive = true,
  onPet,
}) => {
  const [isPet, setIsPet] = React.useState(false);

  const handlePet = () => {
    if (!isInteractive) return;
    setIsPet(true);
    if (onPet) onPet();
    setTimeout(() => setIsPet(false), 800);
  };

  // Dimensions based on size
  const sizeMap = {
    sm: { width: 90, height: 95, viewBoxSize: 120 },
    md: { width: 140, height: 150, viewBoxSize: 120 },
    lg: { width: 200, height: 215, viewBoxSize: 120 },
    hero: { width: 260, height: 280, viewBoxSize: 120 },
  };

  const currentSize = sizeMap[size];

  // Mood configuration
  const moodConfig = {
    idle_happy: {
      auraColor: 'rgba(134, 239, 172, 0.35)',
      leafAngle: 0,
      eyeType: 'happy',
      mouthType: 'smile',
      blushOpacity: 0.6,
      bodyAnimation: {
        y: [0, -6, 0],
        transition: { duration: 3, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    zen_focus: {
      auraColor: 'rgba(167, 243, 208, 0.45)',
      leafAngle: 0,
      eyeType: 'peaceful',
      mouthType: 'calm',
      blushOpacity: 0.5,
      bodyAnimation: {
        scale: [1, 1.05, 1],
        y: [0, -4, 0],
        transition: { duration: 4, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    celebrating: {
      auraColor: 'rgba(253, 224, 71, 0.5)',
      leafAngle: 15,
      eyeType: 'excited',
      mouthType: 'open_joy',
      blushOpacity: 0.85,
      bodyAnimation: {
        y: [0, -14, 0, -8, 0],
        rotate: [0, -3, 3, -1, 0],
        transition: { duration: 0.8, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    sleeping: {
      auraColor: 'rgba(221, 214, 254, 0.45)',
      leafAngle: -8,
      eyeType: 'sleeping',
      mouthType: 'sleepy',
      blushOpacity: 0.4,
      bodyAnimation: {
        y: [0, 3, 0],
        scale: [1, 0.98, 1],
        transition: { duration: 4.5, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    gentle_nudge: {
      auraColor: 'rgba(253, 186, 116, 0.4)',
      leafAngle: 8,
      eyeType: 'curious',
      mouthType: 'tiny_o',
      blushOpacity: 0.7,
      bodyAnimation: {
        rotate: [0, 5, 0],
        y: [0, -3, 0],
        transition: { duration: 2.2, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    comforting: {
      auraColor: 'rgba(221, 214, 254, 0.45)',
      leafAngle: 2,
      eyeType: 'loving',
      mouthType: 'gentle_smile',
      blushOpacity: 0.75,
      bodyAnimation: {
        scale: [1, 1.02, 1],
        y: [0, -3, 0],
        transition: { duration: 3.2, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
    watering_plant: {
      auraColor: 'rgba(110, 231, 183, 0.4)',
      leafAngle: 5,
      eyeType: 'happy',
      mouthType: 'smile',
      blushOpacity: 0.7,
      bodyAnimation: {
        y: [0, -8, 0],
        transition: { duration: 1.8, repeat: Infinity, ease: 'easeInOut' as const },
      },
    },
  }[mood];

  return (
    <div className="flex flex-col items-center select-none relative">
      {/* Dynamic Speech Bubble */}
      {showSpeechBubble && speechText && (
        <AnimatePresence mode="wait">
          <motion.div
            key={speechText}
            initial={{ opacity: 0, y: 8, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -6, scale: 0.95 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            className="mb-3 max-w-xs md:max-w-sm px-4 py-3 rounded-2xl bg-white/95 backdrop-blur-md shadow-sm border border-stone-200/80 text-center relative z-20"
          >
            <p className="text-sm font-medium text-stone-800 leading-snug">{speechText}</p>
            {subtext && <p className="text-xs text-stone-500 mt-1">{subtext}</p>}
            {/* Bubble Tail */}
            <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-4 h-4 bg-white/95 border-r border-b border-stone-200/80 rotate-45" />
          </motion.div>
        </AnimatePresence>
      )}

      {/* Mascot Interactive Wrapper */}
      <motion.div
        animate={isPet ? { scale: [1, 1.15, 0.96, 1], rotate: [0, -6, 6, 0] } : moodConfig.bodyAnimation}
        whileHover={isInteractive ? { scale: 1.04, cursor: 'pointer' } : undefined}
        whileTap={isInteractive ? { scale: 0.96 } : undefined}
        onClick={handlePet}
        onKeyDown={(event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            handlePet();
          }
        }}
        className="relative flex items-center justify-center"
        style={{ width: currentSize.width, height: currentSize.height }}
        role={isInteractive ? 'button' : undefined}
        tabIndex={isInteractive ? 0 : undefined}
        aria-label={`Mascot Lumi, currently ${mood.replace('_', ' ')}`}
      >
        {/* Soft Ambient Aura Glow */}
        <div
          className="absolute inset-0 rounded-full blur-2xl transition-colors duration-700 pointer-events-none"
          style={{
            backgroundColor: moodConfig.auraColor,
            transform: 'scale(1.25)',
          }}
        />

        {/* Petting Hearts Micro-interaction */}
        <AnimatePresence>
          {isPet && (
            <motion.div
              initial={{ opacity: 0, y: 0, scale: 0.5 }}
              animate={{ opacity: 1, y: -30, scale: 1.2 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.6 }}
              className="absolute -top-4 pointer-events-none z-30 flex items-center gap-1 text-rose-400 font-bold text-xs bg-white/90 px-2 py-0.5 rounded-full shadow-xs border border-rose-100"
            >
              <span>+Love</span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* High-Fidelity SVG Mascot */}
        <svg
          viewBox="0 0 120 120"
          className="w-full h-full relative z-10 drop-shadow-sm"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            {/* Body Soft Gradient */}
            <linearGradient id="lumiBodyGrad" x1="60" y1="20" x2="60" y2="105" gradientUnits="userSpaceOnUse">
              <stop stopColor="#FFFFFF" />
              <stop offset="0.75" stopColor="#F9F6F0" />
              <stop offset="1" stopColor="#EFE8DD" />
            </linearGradient>

            {/* Sprout Leaf Gradient */}
            <linearGradient id="leafGrad" x1="60" y1="8" x2="60" y2="30" gradientUnits="userSpaceOnUse">
              <stop stopColor="#4ADE80" />
              <stop offset="1" stopColor="#16A34A" />
            </linearGradient>

            {/* Cozy Blanket Gradient (for comforting mode) */}
            <linearGradient id="blanketGrad" x1="30" y1="65" x2="90" y2="105" gradientUnits="userSpaceOnUse">
              <stop stopColor="#DDD6FE" />
              <stop offset="1" stopColor="#C4B5FD" />
            </linearGradient>

            {/* Nightcap Gradient (for sleeping mode) */}
            <linearGradient id="nightCapGrad" x1="45" y1="12" x2="75" y2="35" gradientUnits="userSpaceOnUse">
              <stop stopColor="#93C5FD" />
              <stop offset="1" stopColor="#3B82F6" />
            </linearGradient>
          </defs>

          {/* SPROUT LEAF ON HEAD */}
          {mood !== 'sleeping' ? (
            <motion.g
              animate={{
                rotate: [moodConfig.leafAngle - 3, moodConfig.leafAngle + 3, moodConfig.leafAngle - 3],
              }}
              transition={{ duration: 2.4, repeat: Infinity, ease: 'easeInOut' }}
              style={{ transformOrigin: '60px 30px' }}
            >
              {/* Stem */}
              <path d="M60 30 C 60 22, 62 18, 63 14" stroke="#15803D" strokeWidth="2.5" strokeLinecap="round" />
              {/* Main Leaf */}
              <path
                d="M63 14 C 64 6, 75 8, 76 17 C 76 24, 66 22, 63 14 Z"
                fill="url(#leafGrad)"
              />
              {/* Secondary Sprout Shoot */}
              <path
                d="M61 20 C 56 16, 50 19, 52 24 C 54 28, 60 25, 61 20 Z"
                fill="#86EFAC"
              />
            </motion.g>
          ) : (
            /* Night Sleeping Cap */
            <g>
              <path
                d="M45 28 C 45 15, 75 14, 75 28 Z"
                fill="url(#nightCapGrad)"
              />
              <path
                d="M72 20 Q 86 24, 88 36"
                stroke="#3B82F6"
                strokeWidth="7"
                strokeLinecap="round"
              />
              <circle cx="89" cy="38" r="4.5" fill="#FFFFFF" />
            </g>
          )}

          {/* MAIN BODY (Organic Cloud-Seedling Silhouette) */}
          <path
            d="M60 26 C 40 26, 28 42, 28 64 C 28 85, 38 102, 60 102 C 82 102, 92 85, 92 64 C 92 42, 80 26, 60 26 Z"
            fill="url(#lumiBodyGrad)"
            stroke="#E5DEC9"
            strokeWidth="1.5"
          />

          {/* SOFT BELLY ACCENT (Subtle warm tone) */}
          <ellipse cx="60" cy="74" rx="22" ry="18" fill="#FDFBF7" opacity="0.9" />

          {/* ROSY BLUSH CHEEKS */}
          <ellipse
            cx="41"
            cy="65"
            rx="5.5"
            ry="3.2"
            fill="#F472B6"
            opacity={moodConfig.blushOpacity}
          />
          <ellipse
            cx="79"
            cy="65"
            rx="5.5"
            ry="3.2"
            fill="#F472B6"
            opacity={moodConfig.blushOpacity}
          />

          {/* EYES LAYER */}
          {moodConfig.eyeType === 'happy' && (
            <g stroke="#292524" strokeWidth="2.5" strokeLinecap="round">
              {/* Happy Arcs (^^) */}
              <path d="M43 57 Q 48 52, 53 57" />
              <path d="M67 57 Q 72 52, 77 57" />
            </g>
          )}

          {moodConfig.eyeType === 'peaceful' && (
            <g stroke="#44403C" strokeWidth="2.5" strokeLinecap="round">
              {/* Peaceful Relaxed Downward Slits */}
              <path d="M43 59 Q 48 62, 53 59" />
              <path d="M67 59 Q 72 62, 77 59" />
            </g>
          )}

          {moodConfig.eyeType === 'excited' && (
            <g>
              {/* Big Sparkling Eyes */}
              <circle cx="48" cy="56" r="5.5" fill="#292524" />
              <circle cx="46.5" cy="54" r="2.2" fill="#FFFFFF" />
              <circle cx="50" cy="58" r="1.1" fill="#FFFFFF" />

              <circle cx="72" cy="56" r="5.5" fill="#292524" />
              <circle cx="70.5" cy="54" r="2.2" fill="#FFFFFF" />
              <circle cx="74" cy="58" r="1.1" fill="#FFFFFF" />
              {/* Gold Sparkle accents */}
              <path d="M33 46 L35 49 L38 50 L35 51 L33 54 L32 51 L29 50 L32 49 Z" fill="#FBBF24" />
              <path d="M87 46 L89 49 L92 50 L89 51 L87 54 L86 51 L83 50 L86 49 Z" fill="#FBBF24" />
            </g>
          )}

          {moodConfig.eyeType === 'curious' && (
            <g>
              {/* One eye wide, one eye relaxed */}
              <circle cx="48" cy="56" r="5" fill="#292524" />
              <circle cx="46.5" cy="54.5" r="1.8" fill="#FFFFFF" />
              <path d="M68 57 Q 72 54, 76 57" stroke="#292524" strokeWidth="2.5" strokeLinecap="round" />
            </g>
          )}

          {moodConfig.eyeType === 'loving' && (
            <g stroke="#292524" strokeWidth="2.5" strokeLinecap="round">
              <path d="M43 57 Q 48 53, 53 57" />
              <path d="M67 57 Q 72 53, 77 57" />
              {/* Soft Tiny Heart overhead */}
              <path
                d="M60 40 C 60 37, 56 36, 56 38.5 C 56 41, 60 43.5, 60 44 C 60 43.5, 64 41, 64 38.5 C 64 36, 60 37, 60 40 Z"
                fill="#FB7185"
              />
            </g>
          )}

          {moodConfig.eyeType === 'sleeping' && (
            <g stroke="#57534E" strokeWidth="2.2" strokeLinecap="round">
              <path d="M44 58 Q 48 61, 52 58" />
              <path d="M68 58 Q 72 61, 76 58" />
              {/* Floating Zzz */}
              <text x="82" y="44" fill="#93C5FD" fontSize="8" fontWeight="bold">z</text>
              <text x="88" y="36" fill="#60A5FA" fontSize="10" fontWeight="bold">Z</text>
            </g>
          )}

          {/* MOUTH LAYER */}
          {moodConfig.mouthType === 'smile' && (
            <path d="M56 65 Q 60 69, 64 65" stroke="#292524" strokeWidth="2.2" strokeLinecap="round" />
          )}

          {moodConfig.mouthType === 'open_joy' && (
            <g>
              <path d="M55 64 Q 60 72, 65 64 Z" fill="#E11D48" />
              <path d="M57 67 Q 60 70, 63 67" fill="#FDA4AF" />
            </g>
          )}

          {moodConfig.mouthType === 'calm' && (
            <path d="M57 66 Q 60 67.5, 63 66" stroke="#44403C" strokeWidth="1.8" strokeLinecap="round" />
          )}

          {moodConfig.mouthType === 'tiny_o' && (
            <ellipse cx="60" cy="67" rx="2.5" ry="3.5" fill="#44403C" />
          )}

          {moodConfig.mouthType === 'gentle_smile' && (
            <path d="M56 66 Q 60 69, 64 66" stroke="#292524" strokeWidth="2.2" strokeLinecap="round" />
          )}

          {moodConfig.mouthType === 'sleepy' && (
            <ellipse cx="60" cy="68" rx="2" ry="2" fill="#57534E" />
          )}

          {/* LITTLE PAWS / HANDS */}
          {mood === 'comforting' ? (
            /* Cozy Knit Blanket & Heart Mug */
            <g>
              <path
                d="M36 78 C 45 72, 75 72, 84 78 C 86 88, 82 96, 60 97 C 38 96, 34 88, 36 78 Z"
                fill="url(#blanketGrad)"
                stroke="#C4B5FD"
                strokeWidth="1"
              />
              {/* Cozy Mug */}
              <rect x="54" y="74" width="12" height="12" rx="3" fill="#FFFFFF" stroke="#A78BFA" strokeWidth="1" />
              <path d="M59 78 Q 60 80, 61 78" stroke="#F43F5E" strokeWidth="1.5" strokeLinecap="round" />
            </g>
          ) : mood === 'watering_plant' ? (
            /* Tiny Watering Can */
            <g>
              <path d="M42 76 C 49 72, 58 73, 63 78 L 60 88 L 43 87 Z" fill="#C7E8D2" stroke="#6CB783" strokeWidth="1.3" />
              <path d="M46 76 C 45 70, 55 68, 58 76" fill="none" stroke="#6CB783" strokeWidth="1.7" strokeLinecap="round" />
              <path d="M61 79 L 72 75 L 75 77 L 64 83" fill="#C7E8D2" stroke="#6CB783" strokeWidth="1.2" strokeLinejoin="round" />
              <circle cx="77" cy="76" r="1.2" fill="#60A5FA" />
              <circle cx="80" cy="80" r="1" fill="#60A5FA" />
              <path d="M52 89 L 52 84 M52 86 C48 82, 46 85, 49 88 M52 86 C56 82, 59 85, 55 88" stroke="#16A34A" strokeWidth="1.8" strokeLinecap="round" />
            </g>
          ) : mood === 'celebrating' ? (
            /* Paws in the air! */
            <g fill="#EFE8DD" stroke="#E5DEC9" strokeWidth="1">
              <ellipse cx="36" cy="50" rx="4.5" ry="4" transform="rotate(-20 36 50)" />
              <ellipse cx="84" cy="50" rx="4.5" ry="4" transform="rotate(20 84 50)" />
            </g>
          ) : (
            /* Resting little marshmallow paws */
            <g fill="#F5EFEB" stroke="#E5DEC9" strokeWidth="1">
              <ellipse cx="46" cy="75" rx="4.5" ry="4" />
              <ellipse cx="74" cy="75" rx="4.5" ry="4" />
            </g>
          )}
        </svg>
      </motion.div>
    </div>
  );
};
