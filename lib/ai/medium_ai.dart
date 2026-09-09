import '../game/game_engine.dart';
import '../game/models.dart';

class MediumAI {
  Move? chooseMove(GameEngine engine) {
    final moves = engine.legalMoves(PlayerSide.opponent);
    if (moves.isEmpty) return null;

    Move best = moves.first;
    double bestValue = double.negativeInfinity;

    for (final move in moves) {
      double value = 0;

      // Immediate score.
      value += move.score * 3.0;

      // Prefer keeping more flexible open ends.
      if (move.resultingLeftEnd != move.resultingRightEnd) {
        value += 2.0;
      }

      // Slightly prefer shedding high-pip tiles.
      value += move.tile.pipSum * 0.35;

      // Basic opponent-risk estimate:
      // multiples of 5 on the table are more tactically "hot".
      final sum = move.openEndsSum;
      if (sum % 5 == 0) value += 1.0;

      if (value > bestValue) {
        bestValue = value;
        best = move;
      }
    }

    return best;
  }
}
