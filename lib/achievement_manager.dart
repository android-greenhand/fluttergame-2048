import 'package:shared_preferences/shared_preferences.dart';

/// 管理游戏成就和彩蛋系统
class AchievementManager {
  static final AchievementManager _instance = AchievementManager._internal();
  factory AchievementManager() => _instance;
  AchievementManager._internal();

  /// SharedPreferences实例，用于存储成就数据
  late SharedPreferences _prefs;
  
  /// 已解锁的成就列表
  final Set<String> _unlockedAchievements = {};
  
  /// 成就键值
  static const String _achieve2048 = 'achieve_2048';
  static const String _achieve4096 = 'achieve_4096';
  static const String _achieve8192 = 'achieve_8192';
  static const String _achievePerfectGame = 'achieve_perfect_game';
  static const String _achieveSpeedrun = 'achieve_speedrun';
  static const String _achieveNoUndo = 'achieve_no_undo';
  
  /// 彩蛋键值
  static const String _easterEggKonami = 'easter_egg_konami';
  static const String _easterEggFibonacci = 'easter_egg_fibonacci';
  static const String _easterEggPalindrome = 'easter_egg_palindrome';

  /// 初始化成就系统
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAchievements();
  }

  /// 从SharedPreferences加载已保存的成就
  void _loadAchievements() {
    final achievements = _prefs.getStringList('achievements') ?? [];
    _unlockedAchievements.addAll(achievements);
  }

  /// 保存成就到SharedPreferences
  Future<void> _saveAchievements() async {
    await _prefs.setStringList('achievements', _unlockedAchievements.toList());
  }

  /// 检查成就是否已解锁
  bool isAchievementUnlocked(String achievement) {
    return _unlockedAchievements.contains(achievement);
  }

  /// 解锁成就
  Future<bool> unlockAchievement(String achievement) async {
    if (!_unlockedAchievements.contains(achievement)) {
      _unlockedAchievements.add(achievement);
      await _saveAchievements();
      return true;
    }
    return false;
  }

  /// 根据游戏状态检查成就
  Future<List<String>> checkAchievements({
    required int score,
    required int moves,
    required Duration gameTime,
    required bool usedUndo,
    required List<List<int>> grid,
  }) async {
    final List<String> newAchievements = [];

    // 检查基于分数的成就
    if (score >= 2048 && await unlockAchievement(_achieve2048)) {
      newAchievements.add(_achieve2048);
    }
    if (score >= 4096 && await unlockAchievement(_achieve4096)) {
      newAchievements.add(_achieve4096);
    }
    if (score >= 8192 && await unlockAchievement(_achieve8192)) {
      newAchievements.add(_achieve8192);
    }

    // 检查完美游戏成就（达到2048时没有小数字）
    if (_isPerfectGame(grid) && await unlockAchievement(_achievePerfectGame)) {
      newAchievements.add(_achievePerfectGame);
    }

    // 检查速通成就（5分钟内达到2048）
    if (score >= 2048 && gameTime.inMinutes < 5 && 
        await unlockAchievement(_achieveSpeedrun)) {
      newAchievements.add(_achieveSpeedrun);
    }

    // 检查无悔棋成就
    if (score >= 2048 && !usedUndo && 
        await unlockAchievement(_achieveNoUndo)) {
      newAchievements.add(_achieveNoUndo);
    }

    return newAchievements;
  }

  /// 检查彩蛋触发条件
  Future<List<String>> checkEasterEggs({
    required List<String> moveHistory,
    required List<List<int>> grid,
  }) async {
    final List<String> newEasterEggs = [];

    // 检查魂斗罗秘籍彩蛋（↑↑↓↓←→←→）
    if (_checkKonamiCode(moveHistory) && 
        await unlockAchievement(_easterEggKonami)) {
      newEasterEggs.add(_easterEggKonami);
    }

    // 检查斐波那契数列彩蛋
    if (_checkFibonacciSequence(grid) && 
        await unlockAchievement(_easterEggFibonacci)) {
      newEasterEggs.add(_easterEggFibonacci);
    }

    // 检查回文数字彩蛋
    if (_checkPalindrome(grid) && 
        await unlockAchievement(_easterEggPalindrome)) {
      newEasterEggs.add(_easterEggPalindrome);
    }

    return newEasterEggs;
  }

  /// 检查是否达成完美游戏（达到2048时没有小于128的数字）
  bool _isPerfectGame(List<List<int>> grid) {
    bool has2048 = false;
    bool hasSmallNumbers = false;

    for (var row in grid) {
      for (var value in row) {
        if (value == 2048) has2048 = true;
        if (value > 0 && value < 128) hasSmallNumbers = true;
      }
    }

    return has2048 && !hasSmallNumbers;
  }

  /// 检查是否输入了魂斗罗秘籍
  bool _checkKonamiCode(List<String> moveHistory) {
    const konamiCode = ['up', 'up', 'down', 'down', 'left', 'right', 'left', 'right'];
    if (moveHistory.length < konamiCode.length) return false;

    final lastMoves = moveHistory.sublist(moveHistory.length - konamiCode.length);
    for (int i = 0; i < konamiCode.length; i++) {
      if (lastMoves[i] != konamiCode[i]) return false;
    }
    return true;
  }

  /// 检查是否形成斐波那契数列
  bool _checkFibonacciSequence(List<List<int>> grid) {
    List<int> numbers = [];
    for (var row in grid) {
      numbers.addAll(row.where((n) => n > 0));
    }
    numbers.sort();

    if (numbers.length < 3) return false;

    for (int i = 2; i < numbers.length; i++) {
      if (numbers[i] != numbers[i-1] + numbers[i-2]) return false;
    }
    return true;
  }

  /// 检查是否形成回文数字模式
  bool _checkPalindrome(List<List<int>> grid) {
    List<int> numbers = [];
    for (var row in grid) {
      numbers.addAll(row.where((n) => n > 0));
    }

    for (int i = 0; i < numbers.length ~/ 2; i++) {
      if (numbers[i] != numbers[numbers.length - 1 - i]) return false;
    }
    return numbers.length >= 4; // 至少需要4个数字才能形成有意义的回文
  }

  /// 获取所有成就的描述
  Map<String, String> get achievementDescriptions => {
    _achieve2048: '达到2048！',
    _achieve4096: '双倍快乐：达到4096！',
    _achieve8192: '超神：达到8192！',
    _achievePerfectGame: '完美游戏：达到2048时没有小于128的数字',
    _achieveSpeedrun: '速通达人：5分钟内达到2048',
    _achieveNoUndo: '勇往直前：不使用撤销功能达到2048',
  };

  /// 获取所有彩蛋的描述
  Map<String, String> get easterEggDescriptions => {
    _easterEggKonami: '魂斗罗秘籍：经典作弊码',
    _easterEggFibonacci: '斐波那契：创建斐波那契数列',
    _easterEggPalindrome: '回文：创建对称数字模式',
  };

  /// 获取已解锁的成就列表
  Set<String> get unlockedAchievements => Set.from(_unlockedAchievements);
} 