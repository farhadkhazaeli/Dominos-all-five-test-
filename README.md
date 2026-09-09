# Dominoes: All Fives — Starter

This starter contains the first working game-logic layer for the agreed rules:

- 2 players
- 28 standard domino tiles
- 7 tiles per player
- 14 tiles in the bank
- First round starts with the highest double
- If neither player has a double, highest tile by pip total starts
- After a drawn round, the same starting rule is used
- Later rounds start with the previous round winner
- Opening tile gives no multiple-of-five score
- Open Ends scoring
- Automatic drawing from the bank until a playable tile is found
- Blocked-round detection
- Lower pip total wins a blocked round
- Equal blocked totals = draw with no points
- End-of-round losing-hand score rounded down to a multiple of 5
- Special case: a lone [0|0] is worth 10 round-end points
- Match target: 350
- Easy AI implemented
- Medium and Hard AI scaffolds included

## Important next steps

1. Add the full game-table UI.
2. Wire human tile taps to `GameEngine.playMove`.
3. Add round transition dialogs.
4. Improve Medium AI with opponent-risk simulation.
5. Improve Hard AI using hidden-information probability / Monte Carlo simulation.
6. Add login and online rooms.
7. Move multiplayer authority to server-side room state.

## Run

Create a Flutter app, replace its `lib/` and `pubspec.yaml` with these files, then:

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```


## Playable UI milestone

The starter now includes a local playable table for **Play vs AI**:

- Difficulty picker routes into the table
- Human hand is visible and selectable
- AI hand stays face-down
- Legal human tiles are enabled
- If one tile can play on both ends, Left / Right choice appears
- Open Ends are shown live
- Scores update during play
- Bank count is visible
- Human and AI automatically draw from the bank until a playable tile is found
- AI takes its own turn
- Round-end and match-end dialogs are wired
- Next rounds are automatically dealt

The table UI is intentionally functional-first. The next pass can replace the simple numbered domino faces with polished pip-based artwork and the green felt / wooden visual language from the approved mockups.
