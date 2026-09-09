import 'dart:math';
import '../game/game_engine.dart';
import '../game/models.dart';

class EasyAI {
  final Random _random;

  EasyAI({Random? random}) : _random = random ?? Random();

  Move? chooseMove(GameEngine engine) {
    final moves = engine.legalMoves(PlayerSide.opponent);
    if (moves.isEmpty) return null;

    // 70% of the time choose one of the highest immediate-scoring moves.
    // 30% of the time choose a random legal move.
    if (_random.nextDouble() < 0.70) {
      final bestScore = moves.map((m) => m.score).reduce((a, b) => a > b ? a : b);
      final bestMoves = moves.where((m) => m.score == bestScore).toList();
      return bestMoves[_random.nextInt(bestMoves.length)];
    }

    return moves[_random.nextInt(moves.length)];
  }

  /// Executes one full AI turn, including automatic bank draws.
  int takeTurn(GameEngine engine) {
    if (engine.currentTurn != PlayerSide.opponent) {
      throw StateError('Not AI turn.');
    }

    if (engine.legalMoves(PlayerSide.opponent).isEmpty) {
      engine.autoDrawUntilPlayable(PlayerSide.opponent);
    }

    final move = chooseMove(engine);
    if (move == null) {
      final blocked = engine.tryResolveBlockedRound();
      if (blocked == null) {
        engine.currentTurn = PlayerSide.human;
        engine.status = GameStatus.playerTurn;
      }
      return 0;
    }

    return engine.playMove(PlayerSide.opponent, move);
  }
}
