import 'package:flutter/material.dart';
import 'screens/ai_level_screen.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const DominoApp());
}

class DominoApp extends StatelessWidget {
  const DominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dominoes All Fives',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFD2A84A),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _playVsAi(BuildContext context) async {
    final difficulty = await Navigator.push<Difficulty>(
      context,
      MaterialPageRoute(builder: (_) => const AiLevelScreen()),
    );

    if (difficulty != null && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(difficulty: difficulty),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dominoes • All Fives'),
        actions: const [
          IconButton(onPressed: null, icon: Icon(Icons.settings)),
          IconButton(onPressed: null, icon: Icon(Icons.language)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.casino, size: 72),
              const SizedBox(height: 22),
              const Text(
                'DOMINOES',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const Text('All Fives'),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _playVsAi(context),
                  icon: const Icon(Icons.smart_toy),
                  label: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('PLAY VS AI'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.public),
                  label: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('PLAY ONLINE'),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.login),
                  title: Text('Log in'),
                  subtitle: Text('Your name appears here after login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
