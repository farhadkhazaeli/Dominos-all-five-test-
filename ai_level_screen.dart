import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

class AiLevelScreen extends StatelessWidget {
  const AiLevelScreen({super.key});

  Widget _button(
    BuildContext context,
    String title,
    String subtitle,
    Difficulty difficulty,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, difficulty),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Difficulty')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _button(context, 'EASY', 'Relaxed', Difficulty.easy),
            _button(context, 'MEDIUM', 'Smart', Difficulty.medium),
            _button(context, 'HARD', 'Strategic', Difficulty.hard),
          ],
        ),
      ),
    );
  }
}
