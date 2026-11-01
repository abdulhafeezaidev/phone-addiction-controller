import React, { useState } from 'react';
import { DESIGN_TOKENS, ColorToken } from '../design-system/tokens';
import { Copy, Check, Palette, Sparkles, Smartphone, Type, Layers } from 'lucide-react';

export const DesignTokensGallery: React.FC = () => {
  const [copiedHex, setCopiedHex] = useState<string | null>(null);

  const handleCopyHex = (hex: string) => {
    navigator.clipboard.writeText(hex);
    setCopiedHex(hex);
    setTimeout(() => setCopiedHex(null), 1800);
  };

  return (
    <div className="space-y-8">
      {/* 1. PALETTES SECTION */}
      <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 bg-emerald-50 rounded-2xl text-emerald-700">
            <Palette className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-xl font-semibold text-stone-900 tracking-tight">Supportive Color Architecture</h3>
            <p className="text-xs text-stone-500 mt-0.5">Click any swatch to copy Hex codes for your frontend development agent</p>
          </div>
        </div>

        <div className="space-y-8">
          {DESIGN_TOKENS.palettes.map((family) => (
            <div key={family.family} className="space-y-3">
              <div className="border-b border-stone-100 pb-2">
                <h4 className="text-sm font-bold text-stone-900">{family.family}</h4>
                <p className="text-xs text-stone-500">{family.description}</p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
                {family.tokens.map((token: ColorToken) => (
                  <div
                    key={token.name}
                    onClick={() => handleCopyHex(token.hex)}
                    className="p-3.5 rounded-2xl border border-stone-200/80 hover:border-stone-400/80 transition-all cursor-pointer group bg-stone-50/40 hover:bg-white hover:shadow-xs flex flex-col justify-between"
                  >
                    <div>
                      {/* Swatch */}
                      <div
                        className="w-full h-16 rounded-xl mb-3 flex items-end justify-between p-2 shadow-inner border border-black/5"
                        style={{ backgroundColor: token.hex }}
                      >
                        <span
                          className="text-[11px] font-mono font-bold px-2 py-0.5 rounded-md backdrop-blur-md"
                          style={{
                            color: token.textColor,
                            backgroundColor: 'rgba(0,0,0,0.18)',
                          }}
                        >
                          {token.hex}
                        </span>
                        <div
                          className="p-1 rounded-md bg-white/80 opacity-0 group-hover:opacity-100 transition-opacity"
                          title="Copy Hex Code"
                        >
                          {copiedHex === token.hex ? (
                            <Check className="w-3 h-3 text-emerald-700" />
                          ) : (
                            <Copy className="w-3 h-3 text-stone-700" />
                          )}
                        </div>
                      </div>

                      <div className="text-xs font-bold text-stone-900">{token.name}</div>
                      <div className="text-[11px] font-medium text-emerald-700 mt-0.5">{token.role}</div>
                    </div>
                    <div className="text-[11px] text-stone-500 mt-2 line-clamp-2 leading-relaxed">
                      {token.description}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 2. TYPOGRAPHY & SPATIAL SYSTEM */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Typography */}
        <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2.5 bg-amber-50 rounded-2xl text-amber-700">
              <Type className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-stone-900 tracking-tight">Typography Pairing</h3>
              <p className="text-xs text-stone-500 mt-0.5">Gentle, rounded authority with high contrast legibility</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="p-4 bg-stone-50 rounded-2xl border border-stone-100">
              <span className="text-[10px] font-bold uppercase tracking-wider text-stone-400 block mb-1">
                Display Font
              </span>
              <div className="text-xl font-bold text-stone-900 font-display">Outfit Display</div>
              <p className="text-xs text-stone-600 mt-1">Used for celebration titles, greeting anchors, and milestone badges.</p>
            </div>

            <div className="p-4 bg-stone-50 rounded-2xl border border-stone-100">
              <span className="text-[10px] font-bold uppercase tracking-wider text-stone-400 block mb-1">
                Body Font
              </span>
              <div className="text-base font-semibold text-stone-800">Plus Jakarta Sans</div>
              <p className="text-xs text-stone-600 mt-1">
                Used for mascot dialogues, mindful friction prompts, and settings.
              </p>
            </div>

            <div className="p-4 bg-stone-50 rounded-2xl border border-stone-100">
              <span className="text-[10px] font-bold uppercase tracking-wider text-stone-400 block mb-1">
                Timer & Data Mono
              </span>
              <div className="text-base font-mono font-bold text-emerald-700">JetBrains Mono (Tabular)</div>
              <p className="text-xs text-stone-600 mt-1">
                Guarantees zero jittering when counting down focus minutes or session durations.
              </p>
            </div>
          </div>
        </div>

        {/* Animation & Haptics */}
        <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2.5 bg-purple-50 rounded-2xl text-purple-700">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-stone-900 tracking-tight">Animation & Haptic Specs</h3>
              <p className="text-xs text-stone-500 mt-0.5">Calming parasympathetic rhythms & tactile sensory reinforcement</p>
            </div>
          </div>

          <div className="space-y-4">
            {DESIGN_TOKENS.animationChoreography.map((anim) => (
              <div key={anim.name} className="p-3.5 bg-stone-50 rounded-2xl border border-stone-100">
                <div className="flex items-center justify-between">
                  <div className="text-xs font-bold text-stone-900">{anim.name}</div>
                  <span className="text-[10px] font-mono bg-white px-2 py-0.5 rounded-md border border-stone-200 text-stone-600">
                    {anim.duration}
                  </span>
                </div>
                <div className="text-[11px] font-mono text-purple-700 mt-1">{anim.easing}</div>
                <p className="text-xs text-stone-500 mt-1.5 leading-relaxed">{anim.description}</p>
              </div>
            ))}

            <div className="pt-2 border-t border-stone-100">
              <span className="text-[10px] font-bold uppercase tracking-wider text-stone-400 block mb-2">
                Haptic Feedback Patterns
              </span>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                {DESIGN_TOKENS.haptics.map((hap) => (
                  <div key={hap.type} className="p-2.5 bg-stone-50 rounded-xl border border-stone-200/60">
                    <div className="text-[11px] font-bold text-stone-800">{hap.type}</div>
                    <div className="text-[10px] font-mono text-emerald-700">{hap.timing}</div>
                    <div className="text-[10px] text-stone-400 mt-0.5">{hap.trigger}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
