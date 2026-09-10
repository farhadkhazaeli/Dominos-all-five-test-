import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../ai/easy_ai.dart';
import '../ai/medium_ai.dart';
import '../ai/hard_ai.dart';
import '../game/domino_tile.dart';
import '../game/game_engine.dart';
import '../game/models.dart';
import 'ai_level_screen.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;

  const GameScreen({
    super.key,
    required this.difficulty,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine engine;
  late EasyAI easyAI;
  late MediumAI mediumAI;
  late HardAI hardAI;

  DominoTile? selectedTile;
  EndSide? selectedSide;

  bool aiThinking = false;
  bool interactionLocked = false;

  DominoTile? animatedTile;
  bool animatedTileFaceUp = true;
  int animationSerial = 0;
  _MotionKind? motionKind;

  String statusMessage = '';

  static const _gold = Color(0xFFD7B66B);
  static const _woodDark = Color(0xFF241710);
  static const _wood = Color(0xFF4A2F1F);
  static const _feltDark = Color(0xFF103729);
  static const _ivory = Color(0xFFF2EBDD);

  @override
  void initState() {
    super.initState();

    engine = GameEngine();
    easyAI = EasyAI();
    mediumAI = MediumAI();
    hardAI = HardAI();

    engine.startMatch();

    statusMessage =
        engine.currentTurn == PlayerSide.human ? 'YOUR TURN' : 'AI STARTS';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (engine.currentTurn == PlayerSide.opponent) {
        await _runAiTurn();
      } else {
        await _ensureHumanCanPlay();
      }
    });
  }

  List<Move> get _humanMoves => engine.legalMoves(PlayerSide.human);

  List<Move> _movesForTile(DominoTile tile) =>
      _humanMoves.where((m) => m.tile == tile).toList();

  bool _isTilePlayable(DominoTile tile) =>
      _movesForTile(tile).isNotEmpty;

  void _selectTile(DominoTile tile) {
    if (engine.status != GameStatus.playerTurn || interactionLocked) return;

    final moves = _movesForTile(tile);
    if (moves.isEmpty) return;

    setState(() {
      selectedTile = tile;
      selectedSide = moves.length == 1 ? moves.first.side : null;
      statusMessage =
          moves.length == 1 ? 'READY TO PLAY' : 'CHOOSE LEFT OR RIGHT';
    });
  }

  Future<void> _showPlacementMotion(
    DominoTile tile, {
    required bool fromHuman,
  }) async {
    if (!mounted) return;

    setState(() {
      animatedTile = tile;
      animatedTileFaceUp = true;
      motionKind =
          fromHuman ? _MotionKind.humanPlace : _MotionKind.aiPlace;
      animationSerial++;
    });

    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    setState(() {
      animatedTile = null;
      motionKind = null;
    });
  }

  Future<void> _showDrawMotion(
    DominoTile tile, {
    required PlayerSide side,
  }) async {
    if (!mounted) return;

    setState(() {
      animatedTile = tile;
      animatedTileFaceUp = side == PlayerSide.human;
      motionKind = side == PlayerSide.human
          ? _MotionKind.humanDraw
          : _MotionKind.aiDraw;
      animationSerial++;

      statusMessage =
          side == PlayerSide.human ? 'DRAWING FROM BANK…' : 'AI DRAWS…';
    });

    await Future.delayed(const Duration(milliseconds: 820));

    if (!mounted) return;
    setState(() {
      animatedTile = null;
      motionKind = null;
    });

    await Future.delayed(const Duration(milliseconds: 220));
  }

  Future<bool> _animatedDrawUntilPlayable(PlayerSide side) async {
    while (engine.legalMoves(side).isEmpty && engine.bank.isNotEmpty) {
      final tile = engine.drawOne(side);
      if (tile == null) break;

      await _showDrawMotion(tile, side: side);

      if (!mounted) return false;
      setState(() {});
    }

    return engine.legalMoves(side).isNotEmpty;
  }

  Future<void> _playSelected() async {
    if (selectedTile == null ||
        engine.status != GameStatus.playerTurn ||
        interactionLocked) {
      return;
    }

    final moves = _movesForTile(selectedTile!);
    if (moves.isEmpty) return;

    Move? move;

    if (moves.length == 1) {
      move = moves.first;
    } else if (selectedSide != null) {
      for (final candidate in moves) {
        if (candidate.side == selectedSide) {
          move = candidate;
          break;
        }
      }
    }

    if (move == null) {
      setState(() => statusMessage = 'CHOOSE LEFT OR RIGHT');
      return;
    }

    final tileToPlay = move.tile;

    setState(() {
      interactionLocked = true;
      statusMessage = 'PLACING TILE…';
    });

    await _showPlacementMotion(tileToPlay, fromHuman: true);
    if (!mounted) return;

    final gained = engine.playMove(PlayerSide.human, move);

    setState(() {
      selectedTile = null;
      selectedSide = null;
      interactionLocked = false;
      statusMessage = gained > 0 ? '+$gained POINTS' : 'TILE PLACED';
    });

    if (engine.status == GameStatus.roundFinished ||
        engine.status == GameStatus.matchFinished) {
      await _handleRoundOrMatchEnd();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 700));
    await _runAiTurn();
  }

  Future<void> _ensureHumanCanPlay() async {
    if (engine.currentTurn != PlayerSide.human ||
        engine.status != GameStatus.playerTurn) {
      return;
    }

    if (_humanMoves.isNotEmpty) {
      if (mounted) {
        setState(() => statusMessage = 'YOUR TURN');
      }
      return;
    }

    setState(() => interactionLocked = true);

    final playable =
        await _animatedDrawUntilPlayable(PlayerSide.human);

    if (!mounted) return;

    setState(() {
      interactionLocked = false;
      statusMessage = playable ? 'YOUR TURN' : 'NO PLAYABLE TILE';
    });

    if (!playable) {
      final blocked = engine.tryResolveBlockedRound();

      if (blocked != null) {
        await _handleRoundOrMatchEnd(result: blocked);
        return;
      }

      engine.currentTurn = PlayerSide.opponent;
      engine.status = GameStatus.aiTurn;

      await Future.delayed(const Duration(milliseconds: 650));
      await _runAiTurn();
    }
  }

  Move? _chooseAiMove() {
    switch (widget.difficulty) {
      case Difficulty.easy:
        return easyAI.chooseMove(engine);
      case Difficulty.medium:
        return mediumAI.chooseMove(engine);
      case Difficulty.hard:
        return hardAI.chooseMove(engine);
    }
  }

  Future<void> _runAiTurn() async {
    if (engine.status != GameStatus.aiTurn ||
        engine.currentTurn != PlayerSide.opponent ||
        aiThinking) {
      return;
    }

    setState(() {
      aiThinking = true;
      interactionLocked = true;
      statusMessage = 'AI IS THINKING…';
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (engine.legalMoves(PlayerSide.opponent).isEmpty) {
      await _animatedDrawUntilPlayable(PlayerSide.opponent);
    }

    if (!mounted) return;

    final move = _chooseAiMove();

    if (move == null) {
      final blocked = engine.tryResolveBlockedRound();

      if (blocked != null) {
        setState(() {
          aiThinking = false;
          interactionLocked = false;
        });

        await _handleRoundOrMatchEnd(result: blocked);
        return;
      }

      engine.currentTurn = PlayerSide.human;
      engine.status = GameStatus.playerTurn;

      setState(() {
        aiThinking = false;
        interactionLocked = false;
        statusMessage = 'YOUR TURN';
      });

      await _ensureHumanCanPlay();
      return;
    }

    setState(() => statusMessage = 'AI PLACES A TILE…');

    await _showPlacementMotion(move.tile, fromHuman: false);
    if (!mounted) return;

    final gained = engine.playMove(PlayerSide.opponent, move);

    setState(() {
      aiThinking = false;
      interactionLocked = false;
      statusMessage =
          gained > 0 ? 'AI SCORES +$gained' : 'AI PLAYED';
    });

    if (engine.status == GameStatus.roundFinished ||
        engine.status == GameStatus.matchFinished) {
      await _handleRoundOrMatchEnd();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 700));

    if (engine.currentTurn == PlayerSide.human) {
      await _ensureHumanCanPlay();
    }
  }

  Future<void> _handleRoundOrMatchEnd({RoundResult? result}) async {
    if (!mounted) return;

    final isMatchEnd = engine.status == GameStatus.matchFinished;

    String title;
    String body;

    if (isMatchEnd) {
      final humanWon = engine.humanScore >= engine.targetScore;
      title = humanWon ? 'You win!' : 'AI wins';
      body = 'Final score: ${engine.humanScore} - ${engine.opponentScore}';
    } else if (result?.draw == true) {
      title = 'Round draw';
      body = 'No points awarded.';
    } else {
      final winner = result?.winner ?? engine.previousRoundWinner;
      final youWon = winner == PlayerSide.human;
      title = youWon ? 'You won the round' : 'AI won the round';

      body = result != null
          ? '+${result.pointsAwarded} round-end points'
          : 'Score: ${engine.humanScore} - ${engine.opponentScore}';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2118),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isMatchEnd ? 'Close' : 'Next round'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (isMatchEnd) {
      Navigator.pop(context);
      return;
    }

    final wasDraw =
        result?.draw == true || engine.previousRoundWinner == null;

    engine.startRound(previousRoundWasDraw: wasDraw);

    setState(() {
      selectedTile = null;
      selectedSide = null;
      interactionLocked = false;
      statusMessage =
          engine.currentTurn == PlayerSide.human ? 'YOUR TURN' : 'AI STARTS';
    });

    if (engine.currentTurn == PlayerSide.opponent) {
      await _runAiTurn();
    } else {
      await _ensureHumanCanPlay();
    }
  }

  Widget _pip() => Container(
        width: 6.2,
        height: 6.2,
        decoration: const BoxDecoration(
          color: Color(0xFF27231F),
          shape: BoxShape.circle,
        ),
      );

  Widget _pipHalf(int value) {
    const spots = <int, List<Alignment>>{
      0: [],
      1: [Alignment.center],
      2: [Alignment.topLeft, Alignment.bottomRight],
      3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
      4: [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ],
      5: [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.center,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ],
      6: [
        Alignment.topLeft,
        Alignment.centerLeft,
        Alignment.bottomLeft,
        Alignment.topRight,
        Alignment.centerRight,
        Alignment.bottomRight,
      ],
    };

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          children: [
            for (final alignment in spots[value] ?? const <Alignment>[])
              Align(alignment: alignment, child: _pip()),
          ],
        ),
      ),
    );
  }

  Widget _domino({
    required int left,
    required int right,
    bool selected = false,
    bool enabled = true,
    bool faceUp = true,
    double scale = 1,
  }) {
    if (!faceUp) {
      return Transform.scale(
        scale: scale,
        child: Container(
          width: 62,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF30231A),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _gold.withOpacity(.65)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                offset: Offset(0, 3),
                color: Colors.black38,
              )
            ],
          ),
          child: Center(
            child: Container(
              width: 38,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: _gold.withOpacity(.42)),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      );
    }

    return Transform.scale(
      scale: scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 62,
        height: 38,
        transform: selected
            ? (Matrix4.identity()..translate(0.0, -5.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? const [Color(0xFFFFFCF4), _ivory]
                : const [Color(0xFFE4DDD1), Color(0xFFC9C1B5)],
          ),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            width: selected ? 2.2 : 1,
            color: selected ? _gold : const Color(0xFF8A8176),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 5,
              offset: Offset(0, 3),
              color: Colors.black38,
            ),
          ],
        ),
        child: Row(
          children: [
            _pipHalf(left),
            Container(width: 1.2, color: const Color(0xFF615A52)),
            _pipHalf(right),
          ],
        ),
      ),
    );
  }

  Widget _scorePanel(
    String name,
    int score, {
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xAA1A1612),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? _gold : Colors.white12,
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: active ? _gold : Colors.white70,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$score',
            style: const TextStyle(
              color: Color(0xFFFFF1CB),
              fontWeight: FontWeight.w700,
              fontSize: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _opponentHand() {
    final count = engine.opponentHand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        const baseW = 62.0;
        final scale =
            count <= 7 ? .73 : math.max(.45, constraints.maxWidth / (count * 48));

        return SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: baseW * scale * .78,
                  child: Center(
                    child: _domino(
                      left: 0,
                      right: 0,
                      faceUp: false,
                      scale: scale,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bankBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xAA16110D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_outlined, size: 16, color: _gold),
          const SizedBox(width: 5),
          Text(
            'BANK ${engine.bank.length}',
            style: const TextStyle(
              color: Color(0xFFE9D6A4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Entire chain is always kept inside the visible board.
  /// As the chain grows:
  /// 1) tiles shrink gradually;
  /// 2) rows are added;
  /// 3) row direction alternates, creating a snake layout.
  Widget _responsiveBoardChain() {
    if (engine.board.isEmpty) {
      return const Center(
        child: Text(
          'PLACE THE OPENING TILE',
          style: TextStyle(
            color: Colors.white38,
            letterSpacing: 1.7,
            fontSize: 12,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final n = engine.board.length;

        const baseW = 62.0;
        const baseH = 38.0;
        const gapX = 2.0;
        const gapY = 5.0;

        double scale = 1.0;
        int perRow = 1;
        int rows = 1;

        // Find the largest scale that fits both width and height.
        for (double candidate = 1.0; candidate >= .50; candidate -= .03) {
          final tileW = baseW * candidate;
          final tileH = baseH * candidate;

          final possiblePerRow =
              math.max(1, ((constraints.maxWidth + gapX) / (tileW + gapX)).floor());

          final neededRows = (n / possiblePerRow).ceil();

          final requiredH =
              neededRows * tileH + math.max(0, neededRows - 1) * gapY;

          if (requiredH <= constraints.maxHeight) {
            scale = candidate;
            perRow = possiblePerRow;
            rows = neededRows;
            break;
          }
        }

        // Final safety fallback for very long chains.
        final tileW = baseW * scale;
        perRow = math.max(
          1,
          ((constraints.maxWidth + gapX) / (tileW + gapX)).floor(),
        );
        rows = (n / perRow).ceil();

        final rowWidgets = <Widget>[];

        for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
          final start = rowIndex * perRow;
          final end = math.min(start + perRow, n);

          final slice = engine.board.sublist(start, end);
          final reverseRow = rowIndex.isOdd;

          final visualTiles = reverseRow
              ? slice.reversed.toList()
              : slice;

          rowWidgets.add(
            SizedBox(
              height: baseH * scale + gapY,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final placed in visualTiles)
                    SizedBox(
                      width: baseW * scale + gapX,
                      child: Center(
                        child: _domino(
                          // When a snake row reverses direction,
                          // swap the two visible halves as well.
                          left: reverseRow
                              ? placed.rightValue
                              : placed.leftValue,
                          right: reverseRow
                              ? placed.leftValue
                              : placed.rightValue,
                          scale: scale,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rowWidgets,
          ),
        );
      },
    );
  }

  Widget _motionOverlay() {
    if (animatedTile == null || motionKind == null) {
      return const SizedBox.shrink();
    }

    Alignment start;
    Alignment end;

    switch (motionKind!) {
      case _MotionKind.humanDraw:
        start = const Alignment(.82, -.52);
        end = const Alignment(0, .90);
        break;
      case _MotionKind.aiDraw:
        start = const Alignment(.82, -.52);
        end = const Alignment(0, -.80);
        break;
      case _MotionKind.humanPlace:
        start = const Alignment(0, .95);
        end = Alignment.center;
        break;
      case _MotionKind.aiPlace:
        start = const Alignment(0, -.82);
        end = Alignment.center;
        break;
    }

    final isDraw = motionKind == _MotionKind.humanDraw ||
        motionKind == _MotionKind.aiDraw;

    return IgnorePointer(
      child: TweenAnimationBuilder<Alignment>(
        key: ValueKey(animationSerial),
        tween: AlignmentTween(begin: start, end: end),
        duration: Duration(milliseconds: isDraw ? 780 : 620),
        curve: Curves.easeInOutCubic,
        builder: (context, alignment, child) => Align(
          alignment: alignment,
          child: child,
        ),
        child: _domino(
          left: animatedTile!.a,
          right: animatedTile!.b,
          faceUp: animatedTileFaceUp,
          scale: 1.04,
        ),
      ),
    );
  }

  Widget _boardArea() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          radius: 1.2,
          colors: [Color(0xFF245E47), _feltDark],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withOpacity(.26)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 8),
            color: Colors.black45,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _FeltPainter()),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x40100D0A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            engine.openEndsLabel,
                            style: const TextStyle(
                              color: Color(0xFFF4DEAA),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .55,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _bankBadge(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                    child: _responsiveBoardChain(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    statusMessage,
                    style: const TextStyle(
                      color: Color(0xFFFFE8AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(child: _motionOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _sideSelector() {
    if (selectedTile == null) return const SizedBox(height: 34);

    final moves = _movesForTile(selectedTile!);
    if (moves.length < 2) return const SizedBox(height: 34);

    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _endChoice('LEFT END', EndSide.left),
          const SizedBox(width: 8),
          _endChoice('RIGHT END', EndSide.right),
        ],
      ),
    );
  }

  Widget _endChoice(String label, EndSide side) {
    final active = selectedSide == side;

    return InkWell(
      onTap: interactionLocked
          ? null
          : () => setState(() => selectedSide = side),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _gold.withOpacity(.18) : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? _gold : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFFFE6A7) : Colors.white54,
            fontSize: 10,
            letterSpacing: .8,
          ),
        ),
      ),
    );
  }

  Widget _humanHand(bool humanTurn) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = engine.humanHand.length;
        const baseW = 62.0;

        final desiredScale = count <= 7
            ? 1.0
            : math.max(.58, constraints.maxWidth / (count * 66));

        final itemWidth = math.max(38.0, baseW * desiredScale + 3);

        return SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final tile in engine.humanHand)
                SizedBox(
                  width: itemWidth,
                  child: GestureDetector(
                    onTap: humanTurn && _isTilePlayable(tile)
                        ? () => _selectTile(tile)
                        : null,
                    child: Center(
                      child: _domino(
                        left: tile.a,
                        right: tile.b,
                        selected: selectedTile == tile,
                        enabled:
                            (humanTurn && _isTilePlayable(tile)) || !humanTurn,
                        scale: desiredScale,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final humanTurn =
        engine.status == GameStatus.playerTurn &&
        engine.currentTurn == PlayerSide.human &&
        !interactionLocked;

    return Scaffold(
      backgroundColor: _woodDark,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_woodDark, _wood, Color(0xFF2A1A12)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: interactionLocked
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFFE8D6AE),
                          size: 18,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'DOMINOES  •  ALL FIVES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFECDCB8),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.15,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Center(
                          child: Text(
                            widget.difficulty.name.toUpperCase(),
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 8.5,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _scorePanel(
                      'AI',
                      engine.opponentScore,
                      active: engine.currentTurn == PlayerSide.opponent,
                    ),
                    _scorePanel(
                      'YOU',
                      engine.humanScore,
                      active: engine.currentTurn == PlayerSide.human,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _opponentHand(),
                const SizedBox(height: 5),
                Expanded(child: _boardArea()),
                const SizedBox(height: 3),
                _sideSelector(),
                _humanHand(humanTurn),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC19A4A),
                      foregroundColor: const Color(0xFF1A130D),
                      disabledBackgroundColor: const Color(0xFF574735),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: humanTurn && selectedTile != null
                        ? _playSelected
                        : null,
                    child: const Text(
                      'PLAY TILE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MotionKind {
  humanDraw,
  aiDraw,
  humanPlace,
  aiPlace,
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.018)
      ..strokeWidth = .55;

    for (double y = 6; y < size.height; y += 8) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

