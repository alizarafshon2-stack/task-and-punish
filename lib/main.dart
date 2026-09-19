import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Камера не найдена: $e");
  }
  runApp(const TaskAndPunishApp());
}

class TaskAndPunishApp extends StatelessWidget {
  const TaskAndPunishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task&Punish',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        primaryColor: const Color(0xFFFF3B30),
      ),
      home: const MainRouter(),
    );
  }
}

class MainRouter extends StatefulWidget {
  const MainRouter({super.key});

  @override
  State<MainRouter> createState() => _MainRouterState();
}

class _MainRouterState extends State<MainRouter> {
  bool _isNewUser = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  _checkRegistration() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool registered = prefs.getBool('registered') ?? false;
    setState(() {
      _isNewUser = !registered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isNewUser ? const OnboardingScreen() : const HomeScreen();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _bioController = TextEditingController();
  final _weaknessController = TextEditingController();
  final _hateController = TextEditingController();

  _saveProfile() async {
    if (_bioController.text.isEmpty || _weaknessController.text.isEmpty || _hateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля! Нам нужно знать ваши слабости.')),
      );
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_bio', _bioController.text);
    await prefs.setString('user_weakness', _weaknessController.text);
    await prefs.setString('user_hate', _hateController.text);
    await prefs.setBool('registered', true);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    '💥 TASK & PUNISH',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Color(0xFFFF3B30)),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'СНАЧАЛА ПОЗНАКОМИМСЯ.\nОтветь честно. Так наказание будет яростнее.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 30),
                _buildField('1. Кто вы и чем занимаетесь?', _bioController, 'Например: Школьник, ищу работу'),
                _buildField('2. Ваши главные хобби и слабости?', _weaknessController, 'Например: Игры, соцсети, энергетики'),
                _buildField('3. Что больше всего ненавидите делать?', _hateController, 'Например: Приседать, учить уроки'),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
                    onPressed: _saveProfile,
                    child: const Text('ПОДПИСАТЬ КОНТРАКТ ДИСЦИПЛИНЫ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String title, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1A1D26),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _taskController = TextEditingController();
  
  TimeOfDay _selectedAlarmTime = const TimeOfDay(hour: 1, minute: 0);
  int _timerDurationMinutes = 15;

  String _voiceMode = 'Mat';
  bool _isMonitoring = false;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _startMonitoring() {
    if (_taskController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Какую задачу мы контролируем? Запиши её.')));
      return;
    }

    DateTime now = DateTime.now();
    DateTime targetTime;

    if (_tabController.index == 0) {
      targetTime = DateTime(now.year, now.month, now.day, _selectedAlarmTime.hour, _selectedAlarmTime.minute);
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }
    } else {
      targetTime = now.add(Duration(minutes: _timerDurationMinutes));
    }

    setState(() {
      _isMonitoring = true;
      _timeLeft = targetTime.difference(DateTime.now());
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = targetTime.difference(DateTime.now());
      if (diff.isNegative || diff.inSeconds <= 0) {
        _countdownTimer?.cancel();
        _triggerLockscreen();
      } else {
        setState(() {
          _timeLeft = diff;
        });
      }
    });
  }

  void _triggerLockscreen() {
    setState(() {
      _isMonitoring = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PunishmentLockScreen(
          taskTitle: _taskController.text,
          voiceMode: _voiceMode,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 TASK & PUNISH v1.0', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Что ты должен сделать?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _taskController,
                enabled: !_isMonitoring,
                decoration: InputDecoration(
                  hintText: 'Например: Не дрочить до часа ночи / выучить уроки',
                  filled: true,
                  fillColor: const Color(0xFF1A1D26),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              if (!_isMonitoring) ...[
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFFF3B30),
                  tabs: const [
                    Tab(text: '⏱️ БУДИЛЬНИК'),
                    Tab(text: '⏳ ТАЙМЕР'),
                  ],
                ),
                SizedBox(
                  height: 100,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: _selectedAlarmTime);
                            if (picked != null) setState(() => _selectedAlarmTime = picked);
                          },
                          child: Text(
                            'Время: ${_selectedAlarmTime.format(context)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
                          ),
                        ),
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [5, 15, 30, 45, 60].map((mins) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Text('$mins мин'),
                                selected: _timerDurationMinutes == mins,
                                onSelected: (sel) => setState(() => _timerDurationMinutes = mins),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Режим ИИ-Сержанта:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('🤬 Мат 18+'),
                      value: 'Mat',
                      groupValue: _voiceMode,
                      onChanged: _isMonitoring ? null : (val) => setState(() => _voiceMode = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('🗣️ Строгий'),
                      value: 'Strict',
                      groupValue: _voiceMode,
                      onChanged: _isMonitoring ? null : (val) => setState(() => _voiceMode = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              if (_isMonitoring) ...[
                Center(
                  child: Column(
                    children: [
                      const Text('⏳ ИДЕТ ОБРАТНЫЙ ОТСЧЕТ', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(
                        '${_timeLeft.inHours.toString().padLeft(2, '0')}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.black, color: Color(0xFFFF3B30)),
                      ),
                    ],
                  ),
                )
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
                    onPressed: _startMonitoring,
                    child: const Text('🔥 ЗАПУСТИТЬ РЕЖИМ КОНТРОЛЯ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class PunishmentLockScreen extends StatefulWidget {
  final String taskTitle;
  final String voiceMode;

  const PunishmentLockScreen({super.key, required this.taskTitle, required this.voiceMode});

  @override
  State<PunishmentLockScreen> createState() => _PunishmentLockScreenState();
}

class _PunishmentLockScreenState extends State<PunishmentLockScreen> {
  CameraController? _cameraController;
  FlutterTts _tts = FlutterTts();
  
  int _repCounter = 0;
  bool _isMoving = false;
  double _motionIntensity = 0.0;
  
  Timer? _shoutingTimer;
  Timer? _sosTimer;
  int _secondsNoMotion = 0;
  bool _sosTriggered = false;
  String _gpsCoordinates = "Определение GPS...";
  
  String _userBio = "ленивый";
  String _userWeakness = "слабости";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _initCamera();
    _initSensors();
    _initVoiceEngine();
    _startSentryTimers();
  }

  _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userBio = prefs.getString('user_bio') ?? "ленивый";
      _userWeakness = prefs.getString('user_weakness') ?? "слабости";
    });
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    final frontCam = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(frontCam, ResolutionPreset.low, enableAudio: false);
    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _cameraController?.startImageStream((CameraImage image) {
        _analyzeMotion(image);
      });
    });
  }

  void _analyzeMotion(CameraImage image) {
    int totalY = 0;
    int pixelCount = image.planes[0].bytes.length;
    for (int i = 0; i < pixelCount; i += 100) {
      totalY += image.planes[0].bytes[i];
    }
    double avgBrightness = totalY / (pixelCount / 100);

    if (avgBrightness < 10) {
      _triggerBlackoutWarning();
      return;
    }

    double currentSum = 0;
    for (int i = 0; i < image.planes[0].bytes.length; i += 50) {
      currentSum += image.planes[0].bytes[i];
    }
    
    double diff = (currentSum / image.planes[0].bytes.length).abs();
    setState(() {
      _motionIntensity = diff;
    });

    if (diff > 12.0 && !_isMoving) {
      _isMoving = true;
    } else if (diff < 5.0 && _isMoving) {
      _isMoving = false;
      _registerRep();
    }
  }

  void _initSensors() {
    userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double motion = event.y.abs() + event.x.abs() + event.z.abs();
      if (motion > 15.0 && !_isMoving) {
        _isMoving = true;
      } else if (motion < 5.0 && _isMoving) {
        _isMoving = false;
        _registerRep();
      }
    });
  }

  void _registerRep() {
    if (_repCounter >= 30) return;
    setState(() {
      _repCounter++;
      _secondsNoMotion = 0;
    });
    if (_repCounter >= 30) {
      _unlockApp();
    }
  }

  void _initVoiceEngine() async {
    await _tts.setLanguage("ru-RU");
    await _tts.setPitch(0.85);
    await _tts.setSpeechRate(0.55);
    _shoutGreeting();
  }

  void _shoutGreeting() {
    String text = widget.voiceMode == 'Mat'
        ? "Еб твою мать! Какого хуя мы не спим?! Дедлайн проебан! Ты же у нас $_userBio! Быстро делай 30 прыжков!"
        : "Внимание! Время вышло. Вы провалили задачу. Выполните тридцать прыжков!";
    _tts.speak(text);
  }

  void _startSentryTimers() {
    _shoutingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_motionIntensity < 4.0) {
        _secondsNoMotion += 3;
        _shoutAtLazyUser();
      } else {
        _secondsNoMotion = 0;
      }
    });

    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsNoMotion >= 60 && !_sosTriggered) {
        _triggerSOS();
      }
    });
  }

  void _shoutAtLazyUser() {
    if (_repCounter >= 30
) return;

    List<String> matPhrases = [
      "Хули ты встал?! А ну прыгай, сука! Осталось ${30 - _repCounter} раз!",
      "Заебал халявить! Твои $_userWeakness тебя не спасут! Работай!",
      "Еб твою мать, движение где?! Я не вижу прыжков! Встал и доделал!",
      "Подними жопу, иначе телефон останется заблокированным!"
    ];

    List<String> strictPhrases = [
      "Никаких остановок! Выполняйте прыжки!",
      "Осталось ${30 - _repCounter} повторений! Сдаваться запрещено!",
      "Соберитесь и доделайте упражнение до конца!"
    ];

    String shout = widget.voiceMode == 'Mat'
        ? (matPhrases..shuffle()).first
        : (strictPhrases..shuffle()).first;

    _tts.speak(shout);
  }

  void _triggerBlackoutWarning() {
    _tts.speak(widget.voiceMode == 'Mat'
        ? "Ты че камеру закрыл, сука?! Я тебя не вижу!"
        : "Камера заблокирована. Пожалуйста, вернитесь в зону видимости.");
  }

  void _triggerSOS() async {
    setState(() {
      _sosTriggered = true;
    });
    _tts.speak("Обнаружена критическая неподвижность! Режим тревоги!");
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _gpsCoordinates = "${position.latitude}, ${position.longitude}";
      });
    } catch (e) {
      setState(() {
        _gpsCoordinates = "GPS недоступен";
      });
    }
  }

  void _unlockApp() {
    _shoutingTimer?.cancel();
    _sosTimer?.cancel();
    _cameraController?.dispose();
    _tts.speak("Наказание завершено. Блокировка снята.");
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _shoutingTimer?.cancel();
    _sosTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: _sosTriggered ? Colors.amber[950] : Colors.red[950],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  _sosTriggered ? '⚠️ ТРЕВОГА SOS ⚠️' : '🚨 ДЕДЛАЙН ПРОВАЛЕН 🚨',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text('Задача: "${widget.taskTitle}"', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _sosTriggered ? Colors.amber : Colors.red, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_cameraController != null && _cameraController!.value.isInitialized)
                          CameraPreview(_cameraController!)
                        else
                          const Center(child: Icon(Icons.camera_alt, size: 64, color: Colors.white24)),
                        
                        Positioned(
                          bottom: 20, left: 20, right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Движение: ${(_motionIntensity * 5).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: (_motionIntensity / 25).clamp(0.0, 1.0),
                                color: Colors.greenAccent,
                                backgroundColor: Colors.white10,
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_sosTriggered) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const Text('Пользователь не двигается более 1 минуты!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Координаты GPS: $_gpsCoordinates', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  )
                ] else ...[
                  Text('$_repCounter / 30', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.black, color: Colors.greenAccent)),
                  const Text('ПРЫЖКОВ ВЫПОЛНЕНО', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
