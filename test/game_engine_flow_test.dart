import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:domino_all_fives/game/game_engine.dart';
import 'package:domino_all_fives/game/models.dart';

void main() {
  test('new match deals 7/7 and leaves 14 in bank', () {
    final engine = GameEngine(random: Random(1));
    engine.startMatch();

    expect(engine.humanHand.length, 7);
    expect(engine.opponentHand.length, 7);
    expect(engine.bank.length, 14);
    expect(engine.board, isEmpty);
  });

  test('opening player always has legal opening moves', () {
    final engine = GameEngine(random: Random(2));
    engine.startMatch();

    final moves = engine.legalMoves(engine.currentTurn);
    expect(moves, isNotEmpty);
  });

  test('after opening move turn passes if round is still active', () {
    final engine = GameEngine(random: Random(3));
    engine.startMatch();

    final starter = engine.currentTurn;
    final move = engine.legalMoves(starter).first;
    engine.playMove(starter, move);

    if (engine.status != GameStatus.roundFinished &&
        engine.status != GameStatus.matchFinished) {
      expect(engine.currentTurn, isNot(starter));
    }
  });
}
