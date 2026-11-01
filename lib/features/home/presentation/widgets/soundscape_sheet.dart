import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/soundscape_service.dart';
import '../../../../core/theme/focus_tokens.dart';

/// Modal bottom sheet for testing Bloomly mindful soundscapes & configuring Lumi's voice.
class SoundscapeSheet extends ConsumerWidget {
  const SoundscapeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SoundscapeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundState = ref.watch(soundscapeProvider);
    final notifier = ref.read(soundscapeProvider.notifier);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: FocusTokens.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6CEBF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: FocusTokens.primary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sanctuary Audio & Voices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: FocusTokens.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Parasympathetic chimes & compassionate voice',
                        style: FocusTokens.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: FocusTokens.inkMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE7DFD5)),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Voice & Soundscape Toggles ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FocusTokens.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE7DFD5)),
                    ),
                    child: Column(
                      children: [
                        // Lumi Voice Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Lumi’s Gentle Voice',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          subtitle: const Text(
                            'Spoken reminders with calm pacing & warm intonation',
                            style: FocusTokens.caption,
                          ),
                          activeThumbColor: FocusTokens.primary,
                          value: soundState.isVoiceEnabled,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            notifier.toggleVoice();
                            if (val) {
                              notifier.speakLumi('Hello friend, I am right here with you.');
                            }
                          },
                        ),
                        const Divider(height: 16, color: Color(0xFFE7DFD5)),
                        // Soundscape Chimes Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Mindful Soundscapes',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          subtitle: const Text(
                            'Harmonic 528Hz bell, kalimba, and singing bowl audio feedback',
                            style: FocusTokens.caption,
                          ),
                          activeThumbColor: FocusTokens.primary,
                          value: soundState.isSoundscapeEnabled,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            notifier.toggleSoundscape();
                            if (val) notifier.playDewdrop();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── 2. Interactive Soundscape Audition Board ──────────────────
                  const Text('AUDITION SOUNDSCAPE TOKENS', style: FocusTokens.eyebrow),
                  const SizedBox(height: 6),
                  const Text(
                    'Replaces compulsive high-pitched app bells with grounded, organic acoustic frequencies.',
                    style: FocusTokens.caption,
                  ),
                  const SizedBox(height: 12),

                  ...kSoundscapeTokens.map((token) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FocusTokens.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7DFD5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.play_arrow_rounded, color: FocusTokens.primary, size: 24),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                notifier.playToken(token.id);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        token.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: FocusTokens.ink,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE7DFD5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        token.category,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: FocusTokens.inkMuted),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  token.musicalKey,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: FocusTokens.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(token.description, style: FocusTokens.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── 3. Ambient Focus Soundscapes ──────────────────────────────
                  const Text('AMBIENT FOCUS SOUNDS', style: FocusTokens.eyebrow),
                  const SizedBox(height: 6),
                  const Text(
                    'Continuous calming audio to accompany your quiet focus sessions.',
                    style: FocusTokens.caption,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: kAmbientSoundscapes.map((ambient) {
                      final isPlaying = soundState.activeAmbient == ambient.id;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.toggleAmbient(ambient.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isPlaying ? const Color(0xFFDCFCE7) : FocusTokens.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPlaying ? FocusTokens.primary : const Color(0xFFE7DFD5),
                                width: isPlaying ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(ambient.icon, style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 6),
                                Text(
                                  ambient.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12,
                                    color: isPlaying ? FocusTokens.primary : FocusTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 14,
                                      color: isPlaying ? FocusTokens.primary : FocusTokens.inkMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isPlaying ? 'Playing' : 'Listen',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isPlaying ? FocusTokens.primary : FocusTokens.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
