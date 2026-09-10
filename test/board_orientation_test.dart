import 'package:flutter_test/flutter_test.dart';
import 'package:domino_all_fives/game/domino_tile.dart';
import 'package:domino_all_fives/game/game_engine.dart';
import 'package:domino_all_fives/game/models.dart';

void main() {
  test('right-side placement keeps matching halves touching', () {
    final engine = GameEngine();

    engine.humanHand = [const DominoTile(6, 2)];
    engine.opponentHand = [const DominoTile(1, 1)];
    engine.bank = [];

    engine.board = [
      const PlacedTile(
        tile: DominoTile(4, 6),
        leftValue: 4,
        rightValue: 6,
      ),
    ];

    engine.leftEnd = 4;
    engine.rightEnd = 6;
    engine.openingMove = false;
    engine.currentTurn = PlayerSide.human;
    engine.status = GameStatus.playerTurn;

    final move = engine
        .legalMoves(PlayerSide.human)
        .firstWhere((m) => m.side == EndSide.right);

    engine.playMove(PlayerSide.human, move);

    expect(engine.board[0].rightValue, 6);
    expect(engine.board[1].leftValue, 6);
    expect(engine.board[1].rightValue, 2);
  });

  test('left-side placement keeps matching halves touching', () {
    final engine = GameEngine();

    engine.humanHand = [const DominoTile(6, 4)];
    engine.opponentHand = [const DominoTile(1, 1)];
    engine.bank = [];

    engine.board = [
      const PlacedTile(
        tile: DominoTile(6, 2),
        leftValue: 6,
        rightValue: 2,
      ),
    ];

    engine.leftEnd = 6;
    engine.rightEnd = 2;
    engine.openingMove = false;
    engine.currentTurn = PlayerSide.human;
    engine.status = GameStatus.playerTurn;

    final move = engine
        .legalMoves(PlayerSide.human)
        .firstWhere((m) => m.side == EndSide.left);

    engine.playMove(PlayerSide.human, move);

    expect(engine.board[0].leftValue, 4);
    expect(engine.board[0].rightValue, 6);
    expect(engine.board[1].leftValue, 6);
  });
}

