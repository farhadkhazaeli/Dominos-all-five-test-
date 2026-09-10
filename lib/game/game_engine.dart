import 'dart:math';
import 'domino_tile.dart';
import 'models.dart';
import 'scoring.dart';

class GameEngine {
  final Random _random;
  final int targetScore;

  List<DominoTile> humanHand = [];
  List<DominoTile> opponentHand = [];
  List<DominoTile> bank = [];

  /// Tiles are stored in the exact orientation in which they appear on table.
  List<PlacedTile> board = [];

  int? leftEnd;
  int? rightEnd;

  int humanScore = 0;
  int opponentScore = 0;

  PlayerSide currentTurn = PlayerSide.human;
  PlayerSide? previousRoundWinner;
  GameStatus status = GameStatus.waitingToStart;
  bool openingMove = true;

  GameEngine({Random? random, this.targetScore = 350})
      : _random = random ?? Random();

  List<DominoTile> _newSet() {
    final tiles = <DominoTile>[];
    for (var i = 0; i <= 6; i++) {
      for (var j = i; j <= 6; j++) {
        tiles.add(DominoTile(i, j));
      }
    }
    return tiles;
  }

  void startMatch() {
    humanScore = 0;
    opponentScore = 0;
    previousRoundWinner = null;
    startRound(isFirstRound: true);
  }

  void startRound({
    bool isFirstRound = false,
    bool previousRoundWasDraw = false,
  }) {
    final tiles = _newSet()..shuffle(_random);

    humanHand = tiles.sublist(0, 7);
    opponentHand = tiles.sublist(7, 14);
    bank = tiles.sublist(14);

    board = [];
    leftEnd = null;
    rightEnd = null;
    openingMove = true;
    status = GameStatus.waitingToStart;

    if (isFirstRound || previousRoundWasDraw || previousRoundWinner == null) {
      currentTurn = _determineFirstStarter();
    } else {
      currentTurn = previousRoundWinner!;
    }

    status = currentTurn == PlayerSide.human
        ? GameStatus.playerTurn
        : GameStatus.aiTurn;
  }

  PlayerSide _determineFirstStarter() {
    final humanBestDouble = _highestDouble(humanHand);
    final opponentBestDouble = _highestDouble(opponentHand);

    if (humanBestDouble != null || opponentBestDouble != null) {
      if (humanBestDouble == null) return PlayerSide.opponent;
      if (opponentBestDouble == null) return PlayerSide.human;
      if (humanBestDouble.a > opponentBestDouble.a) return PlayerSide.human;
      if (opponentBestDouble.a > humanBestDouble.a) return PlayerSide.opponent;
    }

    final humanBest = _highestTile(humanHand);
    final opponentBest = _highestTile(opponentHand);

    final cmp = _compareTilesForStart(humanBest, opponentBest);
    return cmp >= 0 ? PlayerSide.human : PlayerSide.opponent;
  }

  DominoTile? _highestDouble(List<DominoTile> hand) {
    final doubles = hand.where((t) => t.isDouble).toList();
    if (doubles.isEmpty) return null;
    doubles.sort((x, y) => y.a.compareTo(x.a));
    return doubles.first;
  }

  DominoTile _highestTile(List<DominoTile> hand) {
    final copy = [...hand];
    copy.sort((x, y) => _compareTilesForStart(y, x));
    return copy.first;
  }

  int _compareTilesForStart(DominoTile x, DominoTile y) {
    final sum = x.pipSum.compareTo(y.pipSum);
    if (sum != 0) return sum;

    final xHigh = x.a > x.b ? x.a : x.b;
    final yHigh = y.a > y.b ? y.a : y.b;
    final highCmp = xHigh.compareTo(yHigh);
    if (highCmp != 0) return highCmp;

    final xLow = x.a < x.b ? x.a : x.b;
    final yLow = y.a < y.b ? y.a : y.b;
    return xLow.compareTo(yLow);
  }

  List<Move> legalMoves(PlayerSide side) {
    final hand = side == PlayerSide.human ? humanHand : opponentHand;
    final moves = <Move>[];

    if (board.isEmpty) {
      for (final tile in hand) {
        moves.add(Move(
          tile: tile,
          side: EndSide.right,
          resultingLeftEnd: tile.a,
          resultingRightEnd: tile.b,
        ));
      }
      return moves;
    }

    for (final tile in hand) {
      if (tile.matches(leftEnd!)) {
        moves.add(Move(
          tile: tile,
          side: EndSide.left,
          resultingLeftEnd: tile.otherSide(leftEnd!),
          resultingRightEnd: rightEnd!,
        ));
      }

      if (tile.matches(rightEnd!)) {
        moves.add(Move(
          tile: tile,
          side: EndSide.right,
          resultingLeftEnd: leftEnd!,
          resultingRightEnd: tile.otherSide(rightEnd!),
        ));
      }
    }
    return moves;
  }

  /// Draw exactly one tile. UI can animate each individual draw.
  DominoTile? drawOne(PlayerSide side) {
    if (bank.isEmpty) return null;

    final drawn = bank.removeAt(0);
    if (side == PlayerSide.human) {
      humanHand.add(drawn);
    } else {
      opponentHand.add(drawn);
    }
    return drawn;
  }

  bool autoDrawUntilPlayable(PlayerSide side) {
    while (legalMoves(side).isEmpty && bank.isNotEmpty) {
      drawOne(side);
    }
    return legalMoves(side).isNotEmpty;
  }

  int playMove(PlayerSide side, Move move) {
    if (side != currentTurn) {
      throw StateError('It is not $side turn.');
    }

    final legal = legalMoves(side);
    final isLegal = legal.any((m) =>
        m.tile == move.tile &&
        m.side == move.side &&
        m.resultingLeftEnd == move.resultingLeftEnd &&
        m.resultingRightEnd == move.resultingRightEnd);

    if (!isLegal) throw StateError('Illegal move: ${move.tile}');

    final hand = side == PlayerSide.human ? humanHand : opponentHand;
    hand.remove(move.tile);

    if (board.isEmpty) {
      board.add(PlacedTile(
        tile: move.tile,
        leftValue: move.tile.a,
        rightValue: move.tile.b,
      ));
    } else if (move.side == EndSide.left) {
      final oldLeft = leftEnd!;
      board.insert(
        0,
        PlacedTile(
          tile: move.tile,
          leftValue: move.tile.otherSide(oldLeft),
          rightValue: oldLeft,
        ),
      );
    } else {
      final oldRight = rightEnd!;
      board.add(
        PlacedTile(
          tile: move.tile,
          leftValue: oldRight,
          rightValue: move.tile.otherSide(oldRight),
        ),
      );
    }

    leftEnd = move.resultingLeftEnd;
    rightEnd = move.resultingRightEnd;

    final gained = scoreOpenEnds(
      leftEnd!,
      rightEnd!,
      isOpeningMove: openingMove,
    );

    if (side == PlayerSide.human) {
      humanScore += gained;
    } else {
      opponentScore += gained;
    }

    openingMove = false;

    if (hand.isEmpty) {
      finishRoundByEmptyHand(side);
      return gained;
    }

    if (_matchReachedTarget()) {
      status = GameStatus.matchFinished;
      return gained;
    }

    currentTurn =
        side == PlayerSide.human ? PlayerSide.opponent : PlayerSide.human;
    status = currentTurn == PlayerSide.human
        ? GameStatus.playerTurn
        : GameStatus.aiTurn;

    return gained;
  }

  RoundResult finishRoundByEmptyHand(PlayerSide winner) {
    final losingHand =
        winner == PlayerSide.human ? opponentHand : humanHand;
    final award = roundEndAwardFromLosingHand(losingHand);

    if (winner == PlayerSide.human) {
      humanScore += award;
    } else {
      opponentScore += award;
    }

    previousRoundWinner = winner;
    status = _matchReachedTarget()
        ? GameStatus.matchFinished
        : GameStatus.roundFinished;

    return RoundResult(
      winner: winner,
      draw: false,
      pointsAwarded: award,
      reason: 'Player emptied their hand.',
    );
  }

  RoundResult? tryResolveBlockedRound() {
    if (bank.isNotEmpty) return null;
    if (legalMoves(PlayerSide.human).isNotEmpty) return null;
    if (legalMoves(PlayerSide.opponent).isNotEmpty) return null;

    final humanTotal = handPipTotal(humanHand);
    final opponentTotal = handPipTotal(opponentHand);

    if (humanTotal == opponentTotal) {
      previousRoundWinner = null;
      status = GameStatus.roundFinished;
      return const RoundResult(
        winner: null,
        draw: true,
        pointsAwarded: 0,
        reason: 'Blocked round with equal pip totals.',
      );
    }

    final winner =
        humanTotal < opponentTotal ? PlayerSide.human : PlayerSide.opponent;

    final losingHand =
        winner == PlayerSide.human ? opponentHand : humanHand;
    final award = roundEndAwardFromLosingHand(losingHand);

    if (winner == PlayerSide.human) {
      humanScore += award;
    } else {
      opponentScore += award;
    }

    previousRoundWinner = winner;
    status = _matchReachedTarget()
        ? GameStatus.matchFinished
        : GameStatus.roundFinished;

    return RoundResult(
      winner: winner,
      draw: false,
      pointsAwarded: award,
      reason: 'Blocked round; lower pip total wins.',
    );
  }

  bool _matchReachedTarget() =>
      humanScore >= targetScore || opponentScore >= targetScore;

  String get openEndsLabel {
    if (leftEnd == null || rightEnd == null) return 'OPEN ENDS  —';
    final total = leftEnd! + rightEnd!;
    return 'OPEN ENDS   $leftEnd + $rightEnd = $total';
  }
}

