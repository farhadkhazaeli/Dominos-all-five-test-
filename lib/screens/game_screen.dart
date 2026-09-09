import 'dart:async';
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
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    engine = GameEngine();
    easyAI = EasyAI();
    mediumAI = MediumAI();
    hardAI = HardAI();

    engine.startMatch();
    statusMessage = engine.currentTurn == PlayerSide.human
        ? 'Your turn'
        : 'AI starts';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (engine.currentTurn == PlayerSide.opponent) {
        _runAiTurn();
      }
    });
  }

  List<Move> get _humanMoves => engine.legalMoves(PlayerSide.human);

  List<Move> _movesForTile(DominoTile tile) =>
      _humanMoves.where((m) => m.tile == tile).toList();

  bool _isTilePlayable(DominoTile tile) =>
      _movesForTile(tile).isNotEmpty;

  void _selectTile(DominoTile tile) {
    if (engine.status != GameStatus.playerTurn || aiThinking) return;

    final moves = _movesForTile(tile);
    if (moves.isEmpty) return;

    setState(() {
      selectedTile = tile;
      if (moves.length == 1) {
        selectedSide = moves.first.side;
      } else {
        selectedSide = null;
      }
    });
  }

  Future<void> _playSelected() async {
    if (selectedTile == null || engine.status != GameStatus.playerTurn) return;

    final moves = _movesForTile(selectedTile!);
    if (moves.isEmpty) return;

    Move? move;

    if (moves.length == 1) {
      move = moves.first;
    } else if (selectedSide != null) {
      for (final m in moves) {
        if (m.side == selectedSide) {
          move = m;
          break;
        }
      }
    }

    if (move == null) {
      setState(() => statusMessage = 'Choose left or right end');
      return;
    }

    final gained = engine.playMove(PlayerSide.human, move);

    setState(() {
      selectedTile = null;
      selectedSide = null;
      statusMessage = gained > 0 ? '+$gained points' : 'Move played';
    });

    if (engine.status == GameStatus.roundFinished ||
        engine.status == GameStatus.matchFinished) {
      await _handleRoundOrMatchEnd();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 450));
    await _runAiTurn();
  }

  Future<void> _ensureHumanCanPlay() async {
    if (engine.currentTurn != PlayerSide.human ||
        engine.status != GameStatus.playerTurn) {
      return;
    }

    if (_humanMoves.isNotEmpty) return;

    setState(() => statusMessage = 'Drawing from bank...');

    await Future.delayed(const Duration(milliseconds: 350));

    final playable = engine.autoDrawUntilPlayable(PlayerSide.human);

    setState(() {
      statusMessage = playable
          ? 'Playable tile found'
          : 'No playable tile';
    });

    if (!playable) {
      final blocked = engine.tryResolveBlockedRound();
      if (blocked != null) {
        await _handleRoundOrMatchEnd(result: blocked);
        return;
      }

      engine.currentTurn = PlayerSide.opponent;
      engine.status = GameStatus.aiTurn;
      await Future.delayed(const Duration(milliseconds: 450));
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
      statusMessage = 'AI is thinking...';
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (engine.legalMoves(PlayerSide.opponent).isEmpty) {
      engine.autoDrawUntilPlayable(PlayerSide.opponent);
    }

    final move = _chooseAiMove();

    if (move == null) {
      final blocked = engine.tryResolveBlockedRound();
      if (blocked != null) {
        setState(() => aiThinking = false);
        await _handleRoundOrMatchEnd(result: blocked);
        return;
      }

      engine.currentTurn = PlayerSide.human;
      engine.status = GameStatus.playerTurn;
      setState(() {
        aiThinking = false;
        statusMessage = 'Your turn';
      });

      await _ensureHumanCanPlay();
      return;
    }

    final gained = engine.playMove(PlayerSide.opponent, move);

    setState(() {
      aiThinking = false;
      statusMessage = gained > 0
          ? 'AI scored +$gained'
          : 'AI played ${move!.tile}';
    });

    if (engine.status == GameStatus.roundFinished ||
        engine.status == GameStatus.matchFinished) {
      await _handleRoundOrMatchEnd();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 400));

    if (engine.currentTurn == PlayerSide.human) {
      setState(() => statusMessage = 'Your turn');
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
    } else {
      if (result?.draw == true) {
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
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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

    final wasDraw = result?.draw == true || engine.previousRoundWinner == null;
    engine.startRound(previousRoundWasDraw: wasDraw);

    setState(() {
      selectedTile = null;
      selectedSide = null;
      statusMessage = engine.currentTurn == PlayerSide.human
          ? 'Your turn'
          : 'AI starts';
    });

    if (engine.currentTurn == PlayerSide.opponent) {
      await _runAiTurn();
    } else {
      await _ensureHumanCanPlay();
    }
  }

  Widget _scoreCard(String label, int score, {bool highlight = false}) {
    return Expanded(
      child: Card(
        elevation: highlight ? 5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: highlight ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opponentHand() {
    return Wrap(
      spacing: 5,
      alignment: WrapAlignment.center,
      children: List.generate(
        engine.opponentHand.length,
        (index) => Container(
          width: 25,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.black87,
            border: Border.all(color: Colors.white24),
          ),
          child: const Center(
            child: Icon(Icons.circle, size: 6, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _dominoFace(DominoTile tile, {bool selected = false, bool enabled = true}) {
    Widget half(int value) {
      return Expanded(
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: enabled ? Colors.black87 : Colors.black38,
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 58,
      height: 36,
      transform: selected
          ? (Matrix4.identity()..translate(0.0, -4.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.white60,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          width: selected ? 2.5 : 1,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.black26,
        ),
        boxShadow: selected
            ? const [BoxShadow(blurRadius: 8, offset: Offset(0, 3))]
            : null,
      ),
      child: Row(
        children: [
          half(tile.a),
          Container(width: 1, color: Colors.black26),
          half(tile.b),
        ],
      ),
    );
  }

  Widget _boardArea() {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F5A3D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  engine.openEndsLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text('Bank: ${engine.bank.length}'),
            ],
          ),
          const SizedBox(height: 18),
          if (engine.board.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Place the opening tile',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: engine.board
                      .map((tile) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _dominoFace(tile),
                          ))
                      .toList(),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            statusMessage,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _sideSelector() {
    if (selectedTile == null) return const SizedBox.shrink();
    final moves = _movesForTile(selectedTile!);
    if (moves.length < 2) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Left'),
          selected: selectedSide == EndSide.left,
          onSelected: (_) => setState(() => selectedSide = EndSide.left),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text('Right'),
          selected: selectedSide == EndSide.right,
          onSelected: (_) => setState(() => selectedSide = EndSide.right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final humanTurn = engine.status == GameStatus.playerTurn &&
        engine.currentTurn == PlayerSide.human;

    return Scaffold(
      appBar: AppBar(
        title: Text('All Fives • ${widget.difficulty.name.toUpperCase()}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _scoreCard(
                    'AI',
                    engine.opponentScore,
                    highlight: engine.currentTurn == PlayerSide.opponent,
                  ),
                  const SizedBox(width: 8),
                  _scoreCard(
                    'YOU',
                    engine.humanScore,
                    highlight: engine.currentTurn == PlayerSide.human,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _opponentHand(),
              const SizedBox(height: 12),
              Expanded(child: _boardArea()),
              const SizedBox(height: 10),
              _sideSelector(),
              const SizedBox(height: 8),
              SizedBox(
                height: 66,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: engine.humanHand.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final tile = engine.humanHand[index];
                    final playable = humanTurn && _isTilePlayable(tile);
                    return GestureDetector(
                      onTap: playable ? () => _selectTile(tile) : null,
                      child: Center(
                        child: _dominoFace(
                          tile,
                          selected: selectedTile == tile,
                          enabled: playable || !humanTurn,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: humanTurn && selectedTile != null
                      ? _playSelected
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('PLAY TILE'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
