import React from 'react';
import { SUPPORTIVE_UX_PATTERNS, TONE_OF_VOICE_RULES } from '../design-system/supportive-ux-matrix';
import { ShieldAlert, Sparkles, HeartHandshake, Check, X, BookOpen } from 'lucide-react';

export const UXFrameworkGuide: React.FC = () => {
  return (
    <div className="space-y-8">
      {/* 1. RESTRICTIVE VS SUPPORTIVE COMPARISON MATRIX */}
      <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 bg-emerald-50 rounded-2xl text-emerald-700">
            <HeartHandshake className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-xl font-semibold text-stone-900 tracking-tight">
              Supportive vs. Restrictive Interaction Matrix
            </h3>
            <p className="text-xs text-stone-500 mt-0.5">
              How Bloomly shifts phone control from punitive warden to compassionate ally
            </p>
          </div>
        </div>

        <div className="space-y-6">
          {SUPPORTIVE_UX_PATTERNS.map((pattern, idx) => (
            <div
              key={idx}
              className="p-5 rounded-2xl border border-stone-200/80 bg-stone-50/40 hover:bg-stone-50/80 transition-colors"
            >
              <div className="text-xs font-bold uppercase tracking-wider text-stone-400 mb-1">
                Scenario 0{idx + 1}
              </div>
              <h4 className="text-base font-bold text-stone-900 mb-4">{pattern.scenario}</h4>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Traditional Restrictive (Red/Bad) */}
                <div className="p-4 rounded-xl bg-rose-50/60 border border-rose-200/60 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center gap-1.5 text-rose-800 text-xs font-bold mb-2">
                      <X className="w-4 h-4 text-rose-600" />
                      <span>Traditional Restrictive (Punitive)</span>
                    </div>
                    <p className="text-xs text-stone-700 font-medium mb-2">{pattern.traditionalRestrictive.approach}</p>
                    <p className="text-xs text-stone-500 italic mb-2">
                      Psychological flaw: {pattern.traditionalRestrictive.psychologicalImpact}
                    </p>
                  </div>
                  <div className="text-[11px] text-rose-700 bg-rose-100/50 p-2 rounded-lg mt-2">
                    Mascot: {pattern.traditionalRestrictive.mascotReaction}
                  </div>
                </div>

                {/* Bloomly Supportive (Green/Loving) */}
                <div className="p-4 rounded-xl bg-emerald-50/60 border border-emerald-200/70 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center gap-1.5 text-emerald-800 text-xs font-bold mb-2">
                      <Check className="w-4 h-4 text-emerald-600" />
                      <span>Bloomly Supportive (Empowerment)</span>
                    </div>
                    <p className="text-xs text-stone-800 font-medium mb-2">{pattern.bloomlySupportive.approach}</p>
                    <p className="text-xs text-emerald-800/90 mb-2">
                      Why it heals: {pattern.bloomlySupportive.psychologicalImpact}
                    </p>
                  </div>
                  <div className="text-[11px] text-emerald-800 bg-emerald-100/60 p-2 rounded-lg mt-2">
                    Lumi: {pattern.bloomlySupportive.mascotReaction}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 2. TONE OF VOICE & COPYWRITING DIRECTIVE */}
      <div className="bg-white rounded-3xl border border-stone-200/90 shadow-sm p-6 md:p-8">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2.5 bg-amber-50 rounded-2xl text-amber-700">
            <BookOpen className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-stone-900 tracking-tight">Mascot Tone of Voice Directives</h3>
            <p className="text-xs text-stone-500 mt-0.5">
              Copywriting rules your agent must follow across all dialogue generation and notification copy
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Banned Words */}
          <div className="p-5 rounded-2xl bg-stone-50 border border-stone-200/70">
            <div className="flex items-center gap-2 text-rose-700 font-bold text-xs uppercase tracking-wider mb-3">
              <ShieldAlert className="w-4 h-4" />
              <span>Strictly Banned Copy (Triggers Shame & Resistance)</span>
            </div>
            <div className="flex flex-wrap gap-2">
              {TONE_OF_VOICE_RULES.bannedWords.map((word) => (
                <span
                  key={word}
                  className="px-2.5 py-1 rounded-lg bg-rose-100 text-rose-800 text-xs font-medium line-through"
                >
                  {word}
                </span>
              ))}
            </div>
            <p className="text-xs text-stone-500 mt-3 leading-relaxed">
              Never use shame-based adjectives, failure states, or surveillance jargon. When a user spends time on their
              phone, they are often coping with stress or fatigue—judgment only exacerbates screen addiction.
            </p>
          </div>

          {/* Recommended Phrases */}
          <div className="p-5 rounded-2xl bg-emerald-50/50 border border-emerald-200/60">
            <div className="flex items-center gap-2 text-emerald-800 font-bold text-xs uppercase tracking-wider mb-3">
              <Sparkles className="w-4 h-4 text-emerald-600" />
              <span>Recommended Supportive Phrases (Encourages Awareness)</span>
            </div>
            <div className="flex flex-wrap gap-2">
              {TONE_OF_VOICE_RULES.recommendedPhrases.map((phrase) => (
                <span
                  key={phrase}
                  className="px-2.5 py-1 rounded-lg bg-emerald-100 text-emerald-900 text-xs font-semibold"
                >
                  "{phrase}"
                </span>
              ))}
            </div>
            <p className="text-xs text-stone-600 mt-3 leading-relaxed">
              Always frame progress as real life lived and real relationships tended. Center the user as the sovereign
              author of their time, with Lumi as an affectionate guide.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
