import '../game/domino_tile.dart';
import '../game/game_engine.dart';
import '../game/models.dart';

class HardAIMemory {
  final Set<DominoTile> seenTiles = {};
  final Set<int> opponentLikelyMissingNumbers = {};

  void markSeen(DominoTile tile) => seenTiles.add(tile);

  void noteOpponentFailedOnEnds(int leftEnd, int rightEnd) {
    opponentLikelyMissingNumbers.add(leftEnd);
    opponentLikelyMissingNumbers.add(rightEnd);
  }
}

class HardAI {
  final HardAIMemory memory;

  HardAI({HardAIMemory? memory})
      : memory = memory ?? HardAIMemory();

  Move? chooseMove(GameEngine engine) {
    final moves = engine.legalMoves(PlayerSide.opponent);
    if (moves.isEmpty) return null;

    Move best = moves.first;
    double bestValue = double.negativeInfinity;

    for (final move in moves) {
      double value = 0;

      // Immediate points.
      value += move.score * 4.0;

      // Shed dangerous high-pip tiles.
      value += move.tile.pipSum * 0.45;

      // Blocking bonus based on observed opponent shortages.
      if (memory.opponentLikelyMissingNumbers
          .contains(move.resultingLeftEnd)) {
        value += 6.0;
      }
      if (memory.opponentLikelyMissingNumbers
          .contains(move.resultingRightEnd)) {
        value += 6.0;
      }

      // Preserve flexibility where possible.
      if (move.resultingLeftEnd != move.resultingRightEnd) {
        value += 3.0;
      }

      // Small penalty for leaving a very obvious scoring total.
      final sum = move.openEndsSum;
      if (sum % 5 == 0) {
        value -= 1.5;
      }

      if (value > bestValue) {
        bestValue = value;
        best = move;
      }
    }

    return best;
  }
}
