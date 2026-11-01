import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveMascotState, calculateGardenProgress } from './mascot-engine.ts';

test('resolveMascotState returns celebrating response on task completion', () => {
  const result = resolveMascotState({
    activeSession: false,
    timeOfDay: 'afternoon',
    minutesFocusedToday: 120,
    dailyGoalMinutes: 120,
    currentStreakDays: 5,
    lastAction: 'completed_task',
  });

  assert.equal(result.mood, 'celebrating');
  assert.equal(result.expression.mouth, 'open_joy');
  assert.equal(result.animationVariant, 'sparkle');
  assert.match(result.speechText, /You did it/);
});

test('resolveMascotState returns comforting, shame-free response on emergency bypass', () => {
  const result = resolveMascotState({
    activeSession: false,
    timeOfDay: 'afternoon',
    minutesFocusedToday: 30,
    dailyGoalMinutes: 120,
    currentStreakDays: 3,
    lastAction: 'bypass_used',
  });

  assert.equal(result.mood, 'comforting');
  assert.equal(result.expression.eyes, 'loving');
  assert.match(result.speechText, /No guilt here/);
});

test('resolveMascotState returns gentle friction intercept on screen unlock', () => {
  const result = resolveMascotState({
    activeSession: false,
    timeOfDay: 'morning',
    minutesFocusedToday: 10,
    dailyGoalMinutes: 90,
    currentStreakDays: 1,
    lastAction: 'unlocked_screen',
  });

  assert.equal(result.mood, 'gentle_nudge');
  assert.equal(result.expression.eyes, 'curious');
  assert.match(result.speechText, /Checking in with kindness/);
});

test('calculateGardenProgress scales bloom stages correctly', () => {
  assert.equal(calculateGardenProgress(0, 100).bloomState, 'seed');
  assert.equal(calculateGardenProgress(30, 100).bloomState, 'sprout');
  assert.equal(calculateGardenProgress(75, 100).bloomState, 'bud');
  assert.equal(calculateGardenProgress(110, 100).bloomState, 'full_bloom');
});
