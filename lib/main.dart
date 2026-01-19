import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  ));
}

// ==========================================
// 1. SPLASH SCREEN (MENU)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isMusicOn = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _initMusic();
  }

  Future<void> _initMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setSource(AssetSource('sea_theme.mp3'));
    if (isMusicOn) {
      await _audioPlayer.resume();
    }
  }

  void _toggleMusic() {
    setState(() {
      isMusicOn = !isMusicOn;
    });
    if (isMusicOn) {
      _audioPlayer.resume();
    } else {
      _audioPlayer.pause();
    }
  }

  void _startGame() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => NemoGame(
                audioPlayer: _audioPlayer,
                isMusicInitiallyOn: isMusicOn
            )
        )
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DeepSeaBackground()),
          const Positioned(top: 100, left: 50, child: Text("🫧", style: TextStyle(fontSize: 40))),
          const Positioned(top: 300, right: 40, child: Text("🫧", style: TextStyle(fontSize: 60))),

          Positioned(
            top: 50, right: 20,
            child: IconButton(
              icon: Icon(isMusicOn ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 40),
              onPressed: _toggleMusic,
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("🐠 NEMO'S",
                    style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
                const Text("ESCAPE",
                    style: TextStyle(fontSize: 60, color: Colors.orangeAccent, fontWeight: FontWeight.bold, letterSpacing: 5)),
                const SizedBox(height: 50),
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.1).animate(_controller),
                  child: const Text("🦈", style: TextStyle(fontSize: 100)),
                ),
                const SizedBox(height: 80),
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("PLAY NOW", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 2. THE MAIN GAME
// ==========================================
class NemoGame extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final bool isMusicInitiallyOn;

  const NemoGame({
    super.key,
    required this.audioPlayer,
    required this.isMusicInitiallyOn
  });

  @override
  State<NemoGame> createState() => _NemoGameState();
}

class _NemoGameState extends State<NemoGame> with SingleTickerProviderStateMixin {
  // Constants
  static const int gameRefreshRate = 16;
  static const double playerSensitivity = 0.008;
  static const double friction = 0.95;

  // Difficulty Logic
  double get currentSpawnRate {
    double rate = 0.015 + (score * 0.00005);
    return rate > 0.06 ? 0.06 : rate;
  }
  double get currentEnemySpeed {
    double speed = 0.005 + (score * 0.000005);
    return speed > 0.015 ? 0.015 : speed;
  }

  // State
  double nemoX = 0.0;
  double nemoY = 0.8;
  double velocityX = 0.0;
  double velocityY = 0.0;
  double tiltInputX = 0.0;
  double tiltInputY = 0.0;

  List<GameObject> obstacles = [];
  List<Bubble> bubbles = [];
  int score = 0;
  bool isGameOver = false;
  bool isVictory = false; // NEW FLAG FOR VICTORY
  double time = 0;

  StreamSubscription? _streamSubscription;
  Timer? _gameLoop;

  @override
  void initState() {
    super.initState();
    if (!widget.isMusicInitiallyOn) {
      widget.audioPlayer.pause();
    } else {
      if(widget.audioPlayer.state != PlayerState.playing) {
        widget.audioPlayer.resume();
      }
    }
    startGame();
  }

  void startGame() {
    setState(() {
      nemoX = 0.0;
      nemoY = 0.8;
      velocityX = 0.0;
      velocityY = 0.0;
      obstacles = [];
      bubbles = [];
      score = 0;
      isGameOver = false;
      isVictory = false; // Reset victory flag
      time = 0;
    });

    _streamSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      tiltInputX = event.x;
      tiltInputY = event.y;
    });

    _gameLoop = Timer.periodic(const Duration(milliseconds: gameRefreshRate), (timer) {
      if (isGameOver || isVictory) {
        timer.cancel();
        return;
      }
      updateGame();
    });
  }

  void updateGame() {
    setState(() {
      time += 0.1;
      score++;

      // --- VICTORY CHECK ---
      if (score >= 5000) {
        victory();
        return;
      }

      // Physics
      velocityX -= tiltInputX * playerSensitivity * 0.1;
      velocityY += tiltInputY * playerSensitivity * 0.1;
      velocityX *= friction;
      velocityY *= friction;
      nemoX += velocityX;
      nemoY += velocityY;

      // Clamp
      if (nemoX < -1.0) { nemoX = -1.0; velocityX = 0; }
      if (nemoX > 1.0)  { nemoX = 1.0;  velocityX = 0; }
      if (nemoY < -1.0) { nemoY = -1.0; velocityY = 0; }
      if (nemoY > 1.0)  { nemoY = 1.0;  velocityY = 0; }

      // Bubbles
      if (Random().nextDouble() < 0.15) bubbles.add(Bubble());
      for (var bubble in bubbles) {
        bubble.y -= 0.005;
        bubble.x += sin(time + bubble.randomOffset) * 0.005;
      }
      bubbles.removeWhere((b) => b.y < -1.2);

      // Enemies
      if (Random().nextDouble() < currentSpawnRate) {
        obstacles.add(GameObject(
          x: Random().nextDouble() * 2 - 1,
          y: -1.2,
          type: GameObject.getRandomEnemy(score),
        ));
      }
      for (var obj in obstacles) {
        obj.y += currentEnemySpeed * obj.speedMultiplier;
        obj.x += sin(time + obj.randomOffset) * 0.002;
      }
      obstacles.removeWhere((element) => element.y > 1.2);

      checkCollisions();
    });
  }

  void checkCollisions() {
    for (var obstacle in obstacles) {
      double xDist = (nemoX - obstacle.x).abs();
      double yDist = (nemoY - obstacle.y).abs();
      double hitBoxSize = obstacle.getSize() / 400;

      if (xDist < hitBoxSize && yDist < hitBoxSize) {
        gameOver();
      }
    }
  }

  void gameOver() {
    setState(() {
      isGameOver = true;
    });
    _streamSubscription?.cancel();
    _gameLoop?.cancel();
  }

  // --- NEW VICTORY METHOD ---
  void victory() {
    setState(() {
      isVictory = true;
    });
    _streamSubscription?.cancel();
    _gameLoop?.cancel();
  }

  void _quitGame() {
    widget.audioPlayer.dispose();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SplashScreen()));
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DeepSeaBackground()),

          ...bubbles.map((b) => Align(
            alignment: Alignment(b.x, b.y),
            child: Container(
              width: 15 * b.scale,
              height: 15 * b.scale,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            ),
          )),

          ...obstacles.map((obj) => Align(
            alignment: Alignment(obj.x, obj.y),
            child: Transform.rotate(
              angle: sin(time + obj.randomOffset) * 0.1,
              child: Text(obj.getEmoji(), style: TextStyle(fontSize: obj.getSize())),
            ),
          )),

          Align(
            alignment: Alignment(nemoX, nemoY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(velocityX > 0 ? -1.0 : 1.0, 1.0)
                ..rotateZ(sin(time * 3) * 0.15),
              child: const Text("🐠", style: TextStyle(fontSize: 50)),
            ),
          ),

          Positioned(
            top: 50, left: 20,
            child: Text("Score: $score",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5, color: Colors.black)])),
          ),

          // --- GAME OVER SCREEN ---
          if (isGameOver)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2)
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("GAME OVER", style: TextStyle(color: Colors.redAccent, fontSize: 40, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("Score: $score", style: const TextStyle(color: Colors.white, fontSize: 24)),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                              onPressed: _quitGame,
                              child: const Text("Menu", style: TextStyle(color: Colors.white))
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: startGame,
                              child: const Text("Retry", style: TextStyle(color: Colors.white))
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

          // --- BIG F**KING VICTORY SCREEN ---
          if (isVictory)
            Container(
              color: Colors.orange.withOpacity(0.85), // Golden Victory Background
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🎉", style: TextStyle(fontSize: 80)),
                    const SizedBox(height: 10),
                    const Text(
                      "CONGRATS!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(3,3))]
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Nemo is now safe!!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 5, color: Colors.black45, offset: Offset(2,2))]
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text("🐠", style: TextStyle(fontSize: 120)), // Giant Happy Nemo
                    const SizedBox(height: 50),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                      ),
                      onPressed: _quitGame,
                      child: const Text("PLAY AGAIN",
                          style: TextStyle(color: Colors.orange, fontSize: 25, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

// ==========================================
// 3. HELPERS
// ==========================================

enum EnemyType { shark, stone, prawn, starfish, oyster, seahorse, crab, octopus, squid, jellyfish, blowfish, tropicalFish, whale, dolphin, turtle, lobster, ray, urchin }

class GameObject {
  double x, y;
  EnemyType type;
  double randomOffset;
  double speedMultiplier;

  GameObject({required this.x, required this.y, required this.type})
      : randomOffset = Random().nextDouble() * 10,
        speedMultiplier = _getSpeedForType(type);

  static EnemyType getRandomEnemy(int currentScore) {
    List<EnemyType> availablePool = [
      EnemyType.stone, EnemyType.prawn, EnemyType.starfish,
      EnemyType.oyster, EnemyType.seahorse, EnemyType.tropicalFish
    ];
    if (currentScore > 500) availablePool.addAll([EnemyType.crab, EnemyType.octopus, EnemyType.squid, EnemyType.jellyfish, EnemyType.turtle, EnemyType.blowfish]);
    if (currentScore > 1000) availablePool.addAll([EnemyType.shark, EnemyType.whale, EnemyType.dolphin, EnemyType.lobster, EnemyType.ray, EnemyType.urchin]);
    return availablePool[Random().nextInt(availablePool.length)];
  }

  static double _getSpeedForType(EnemyType type) {
    if (type == EnemyType.stone) return 1.2;
    if (type == EnemyType.shark) return 1.3;
    if (type == EnemyType.jellyfish) return 0.7;
    return 1.0;
  }

  String getEmoji() {
    switch (type) {
      case EnemyType.shark: return "🦈";
      case EnemyType.stone: return "🪨";
      case EnemyType.prawn: return "🦐";
      case EnemyType.starfish: return "⭐";
      case EnemyType.oyster: return "🦪";
      case EnemyType.seahorse: return " 🐉 ";
      case EnemyType.crab: return "🦀";
      case EnemyType.octopus: return "🐙";
      case EnemyType.squid: return "🦑";
      case EnemyType.jellyfish: return "🪼";
      case EnemyType.blowfish: return "🐡";
      case EnemyType.tropicalFish: return "🐟";
      case EnemyType.whale: return "🐋";
      case EnemyType.dolphin: return "🐬";
      case EnemyType.turtle: return "🐢";
      case EnemyType.lobster: return "🦞";
      case EnemyType.ray: return "🦈";
      case EnemyType.urchin: return "🌑";
      default: return "🐟";
    }
  }

  double getSize() {
    if (type == EnemyType.whale) return 90;
    if (type == EnemyType.shark) return 70;
    if (type == EnemyType.dolphin) return 65;
    if (type == EnemyType.octopus) return 60;
    if (type == EnemyType.prawn) return 35;
    return 50;
  }
}

class Bubble {
  double x, y, scale, randomOffset;
  Bubble() : x = Random().nextDouble() * 2 - 1, y = 1.2, scale = Random().nextDouble() + 0.5, randomOffset = Random().nextDouble() * 10;
}

class DeepSeaBackground extends StatelessWidget {
  const DeepSeaBackground({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF006994), Color(0xFF001e3d)],
        ),
      ),
    );
  }
}