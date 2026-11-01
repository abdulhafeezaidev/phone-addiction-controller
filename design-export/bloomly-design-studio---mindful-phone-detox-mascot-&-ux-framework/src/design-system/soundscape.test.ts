import test from 'node:test';
import assert from 'node:assert/strict';
import { SOUNDSCAPE_TOKENS, getRecommendedSoundscapeForMood } from './soundscape.ts';

test('SOUNDSCAPE_TOKENS contains all core auditory soundscape tokens', () => {
  assert.equal(SOUNDSCAPE_TOKENS.length >= 5, true);
  const celebrationToken = SOUNDSCAPE_TOKENS.find(t => t.id === 'bell_528_harmony');
  assert.ok(celebrationToken);
  assert.equal(celebrationToken.baseFrequencies[0], 528);
  assert.equal(celebrationToken.category, 'Celebration Chime');
});

test('getRecommendedSoundscapeForMood maps celebrating mood to bell_528_harmony', () => {
  const token = getRecommendedSoundscapeForMood('celebrating');
  assert.equal(token.id, 'bell_528_harmony');
  assert.match(token.name, /528 Hz/);
});

test('getRecommendedSoundscapeForMood maps sleeping mood to singing bowl drone', () => {
  const token = getRecommendedSoundscapeForMood('sleeping');
  assert.equal(token.id, 'singing_bowl_drone');
  assert.match(token.musicalKey, /216 Hz/);
});

test('getRecommendedSoundscapeForMood maps gentle_nudge to dewdrop', () => {
  const token = getRecommendedSoundscapeForMood('gentle_nudge');
  assert.equal(token.id, 'dewdrop_water_pluck');
});
