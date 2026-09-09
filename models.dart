import 'domino_tile.dart';

enum GameStatus {
  waitingToStart,
  playerTurn,
  aiTurn,
  drawingFromBank,
  roundFinished,
  matchFinished,
}

enum PlayerSide { human, opponent }

enum EndSide { left, right }

class PlacedTile {
  final DominoTile tile;
  final int leftValue;
  final int rightValue;

  const PlacedTile({
    required this.tile,
    required this.leftValue,
    required this.rightValue,
  });
}

class Move {
  final DominoTile tile;
  final EndSide side;
  final int resultingLeftEnd;
  final int resultingRightEnd;

  const Move({
    required this.tile,
    required this.side,
    required this.resultingLeftEnd,
    required this.resultingRightEnd,
  });

  int get openEndsSum => resultingLeftEnd + resultingRightEnd;
  int get score =>
      openEndsSum > 0 && openEndsSum % 5 == 0 ? openEndsSum : 0;
}

class RoundResult {
  final PlayerSide? winner;
  final bool draw;
  final int pointsAwarded;
  final String reason;

  const RoundResult({
    required this.winner,
    required this.draw,
    required this.pointsAwarded,
    required this.reason,
  });
}
