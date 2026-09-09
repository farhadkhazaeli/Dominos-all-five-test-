import 'package:flutter_test/flutter_test.dart';
import 'package:domino_all_fives/game/domino_tile.dart';
import 'package:domino_all_fives/game/scoring.dart';

void main() {
  group('Scoring', () {
    test('opening move never scores', () {
      expect(scoreOpenEnds(5, 5, isOpeningMove: true), 0);
    });

    test('open ends score exact multiple of five', () {
      expect(scoreOpenEnds(6, 4, isOpeningMove: false), 10);
      expect(scoreOpenEnds(5, 0, isOpeningMove: false), 5);
      expect(scoreOpenEnds(6, 3, isOpeningMove: false), 0);
    });

    test('round end score rounds down to multiple of five', () {
      expect(floorToFive(36), 35);
      expect(floorToFive(39), 35);
      expect(floorToFive(40), 40);
    });

    test('lone double zero is worth ten at round end', () {
      expect(roundEndAwardFromLosingHand([const DominoTile(0, 0)]), 10);
    });

    test('normal losing hand uses pip total rounded down', () {
      final hand = [
        const DominoTile(6, 5),
        const DominoTile(4, 4),
        const DominoTile(3, 2),
      ];
      expect(handPipTotal(hand), 24);
      expect(roundEndAwardFromLosingHand(hand), 20);
    });
  });
}
