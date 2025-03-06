import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'audio_manager.dart';
import 'achievement_manager.dart';

/// 方块动画状态类
class TileAnimation {
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final int value;

  TileAnimation(this.fromX, this.fromY, this.toX, this.toY, this.value);
}

/// 2048游戏页面
/// 实现了基本的2048游戏逻辑，包括：
/// - 4x4网格布局
/// - 上下左右滑动操作
/// - 相同数字合并
/// - 分数计算
/// - 游戏结束检测
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  GamePageState createState() => GamePageState();
}

class GamePageState extends State<GamePage> with TickerProviderStateMixin {
  // 游戏网格，4x4的二维数组
  List<List<int>> grid = List.generate(4, (_) => List.filled(4, 0));
  // 当前游戏分数
  int score = 0;
  int bestScore = 0; // 最高分
  // 随机数生成器
  final Random random = Random();
  
  // 动画相关变量
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  List<TileAnimation> _animations = [];
  bool _isAnimating = false;

  // 历史记录，用于撤销功能
  List<List<int>> _previousGrid = [];
  int _previousScore = 0;
  bool _canUndo = false;

  // SharedPreferences的键名常量
  static const String _keyBestScore = 'bestScore';
  static const String _keyCurrentScore = 'currentScore';
  static const String _keyGrid = 'grid';

  // 游戏状态追踪变量
  Duration _gameTime = Duration.zero;
  int _moves = 0;
  List<String> _moveHistory = [];
  bool _usedUndo = false;
  late DateTime _gameStartTime;

  // 管理器实例
  final AudioManager _audioManager = AudioManager();
  final AchievementManager _achievementManager = AchievementManager();

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    // 初始化音频和成就系统
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await _audioManager.init();
    await _achievementManager.init();
    await _loadGameData();
    _gameStartTime = DateTime.now();
    _audioManager.playBackgroundMusic();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _audioManager.dispose();
    super.dispose();
  }

  /// 加载保存的游戏数据
  Future<void> _loadGameData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        // 加载最高分
        bestScore = prefs.getInt(_keyBestScore) ?? 0;
        
        // 加载当前分数
        score = prefs.getInt(_keyCurrentScore) ?? 0;
        
        // 加载网格数据
        String? gridJson = prefs.getString(_keyGrid);
        if (gridJson != null) {
          List<dynamic> gridData = json.decode(gridJson);
          grid = gridData.map((row) => List<int>.from(row)).toList();
        } else {
          initGame();
        }
      });
    } catch (e) {
      print('加载游戏数据时出错: $e');
      initGame();
    }
  }

  /// 保存游戏数据
  Future<void> _saveGameData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_keyBestScore, bestScore);
      await prefs.setInt(_keyCurrentScore, score);
      await prefs.setString(_keyGrid, json.encode(grid));
    } catch (e) {
      print('保存游戏数据时出错: $e');
    }
  }

  /// 初始化游戏
  /// 清空网格并添加两个初始数字
  void initGame() {
    grid = List.generate(4, (_) => List.filled(4, 0));
    addNewTile();
    addNewTile();
    _saveGameData(); // 保存初始状态
  }

  /// 在空位置添加新的数字
  /// 90%概率生成2，10%概率生成4
  void addNewTile() {
    List<Point> emptyTiles = [];
    
    // 找出所有空位置
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) {
          emptyTiles.add(Point(i, j));
        }
      }
    }
    
    // 如果没有空位置，直接返回
    if (emptyTiles.isEmpty) return;

    // 随机选择一个空位置
    Point randomPoint = emptyTiles[random.nextInt(emptyTiles.length)];
    // 90%概率生成2，10%概率生成4
    grid[randomPoint.x.toInt()][randomPoint.y.toInt()] = random.nextInt(10) < 9 ? 2 : 4;
  }

  /// 处理移动操作
  /// [direction] 移动方向
  void move(DragDirection direction) {
    bool moved = false;
    
    // 记录移动前的网格状态，用于检测是否发生变化
    List<List<int>> oldGrid = List.generate(
      4, (i) => List.from(grid[i])
    );

    // 根据方向执行相应的移动操作
    switch (direction) {
      case DragDirection.up:
        moved = moveUp();
        break;
      case DragDirection.down:
        moved = moveDown();
        break;
      case DragDirection.left:
        moved = moveLeft();
        break;
      case DragDirection.right:
        moved = moveRight();
        break;
    }

    // 如果发生了移动，添加新的数字并检查游戏是否结束
    if (moved) {
      addNewTile();
      _saveGameData(); // 保存游戏状态
      if (isGameOver()) {
        showGameOverDialog();
      }
    }
  }

  /// 向左移动
  bool moveLeft() {
    bool moved = false;
    for (int i = 0; i < 4; i++) {
      List<int> row = grid[i];
      List<int> newRow = mergeTiles(row);
      if (!listEquals(row, newRow)) {
        moved = true;
        grid[i] = newRow;
        _audioManager.playMergeSound();
      }
    }
    return moved;
  }

  /// 向右移动
  bool moveRight() {
    bool moved = false;
    for (int i = 0; i < 4; i++) {
      // 反转行，执行左移操作，再反转回来
      List<int> row = grid[i].reversed.toList();
      List<int> newRow = mergeTiles(row).reversed.toList();
      if (!listEquals(grid[i], newRow)) {
        moved = true;
        grid[i] = newRow;
        _audioManager.playMergeSound();
      }
    }
    return moved;
  }

  /// 向上移动
  bool moveUp() {
    bool moved = false;
    for (int j = 0; j < 4; j++) {
      // 获取每一列
      List<int> column = [grid[0][j], grid[1][j], grid[2][j], grid[3][j]];
      List<int> newColumn = mergeTiles(column);
      if (!listEquals(column, newColumn)) {
        moved = true;
        // 更新列数据
        for (int i = 0; i < 4; i++) {
          grid[i][j] = newColumn[i];
        }
        _audioManager.playMergeSound();
      }
    }
    return moved;
  }

  /// 向下移动
  bool moveDown() {
    bool moved = false;
    for (int j = 0; j < 4; j++) {
      // 获取每一列并反转
      List<int> column = [grid[0][j], grid[1][j], grid[2][j], grid[3][j]].reversed.toList();
      List<int> newColumn = mergeTiles(column).reversed.toList();
      if (!listEquals([grid[0][j], grid[1][j], grid[2][j], grid[3][j]], newColumn)) {
        moved = true;
        // 更新列数据
        for (int i = 0; i < 4; i++) {
          grid[i][j] = newColumn[i];
        }
        _audioManager.playMergeSound();
      }
    }
    return moved;
  }

  /// 合并相同数字的方块
  /// 返回合并后的新数组
  List<int> mergeTiles(List<int> line) {
    // 移除所有0
    List<int> nonZeros = line.where((x) => x != 0).toList();
    List<int> result = List.filled(4, 0);
    int index = 0;
    
    // 合并相邻的相同数字
    for (int i = 0; i < nonZeros.length; i++) {
      if (i < nonZeros.length - 1 && nonZeros[i] == nonZeros[i + 1]) {
        result[index] = nonZeros[i] * 2;
        score += nonZeros[i] * 2;
        if (score > bestScore) {
          bestScore = score;
        }
        i++;
      } else {
        result[index] = nonZeros[i];
      }
      index++;
    }
    
    return result;
  }

  /// 检查游戏是否结束
  bool isGameOver() {
    // 检查是否有空格
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) return false;
      }
    }
    
    // 检查是否有相邻的相同数字
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        // 检查右边
        if (j < 3 && grid[i][j] == grid[i][j + 1]) return false;
        // 检查下边
        if (i < 3 && grid[i][j] == grid[i + 1][j]) return false;
      }
    }
    
    return true;
  }

  /// 显示游戏结束对话框
  void showGameOverDialog() {
    _audioManager.playGameOverSound();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAF8EF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '游戏结束',
            style: TextStyle(
              color: Color(0xFF776E65),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '最终得分: $score',
                style: const TextStyle(
                  color: Color(0xFF776E65),
                  fontSize: 20,
                ),
              ),
              if (score > bestScore) ...[
                const SizedBox(height: 16),
                const Text(
                  '新纪录！',
                  style: TextStyle(
                    color: Color(0xFFF65E3B),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  if (score > bestScore) {
                    bestScore = score;
                  }
                  score = 0;
                  _canUndo = false;
                  initGame();
                });
                await _saveGameData(); // 保存新的游戏状态
              },
              child: const Text(
                '重新开始',
                style: TextStyle(
                  color: Color(0xFF8F7A66),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8F7A66),
        foregroundColor: Colors.white,
        elevation: 4,
        title: const Text(
          '2048',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // 教程按钮
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showTutorial,
            tooltip: '游戏说明',
          ),
          // 撤销按钮
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undoMove : null,
            tooltip: '撤销',
          ),
          // 重新开始按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                score = 0;
                initGame();
              });
            },
            tooltip: '重新开始',
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: '设置',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // 分数显示
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildScoreBox('当前分数', score)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildScoreBox('最高分数', bestScore)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 游戏说明
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '滑动手指合并相同的数字，努力达到2048！',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // 游戏网格
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFBBADA0),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.velocity.pixelsPerSecond.dy < -250) {
                                _saveStateForUndo();
                                setState(() {
                                  move(DragDirection.up);
                                  _moves++;
                                  _moveHistory.add('up');
                                  _checkAchievements();
                                });
                              } else if (details.velocity.pixelsPerSecond.dy > 250) {
                                _saveStateForUndo();
                                setState(() {
                                  move(DragDirection.down);
                                  _moves++;
                                  _moveHistory.add('down');
                                  _checkAchievements();
                                });
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              if (details.velocity.pixelsPerSecond.dx < -250) {
                                _saveStateForUndo();
                                setState(() {
                                  move(DragDirection.left);
                                  _moves++;
                                  _moveHistory.add('left');
                                  _checkAchievements();
                                });
                              } else if (details.velocity.pixelsPerSecond.dx > 250) {
                                _saveStateForUndo();
                                setState(() {
                                  move(DragDirection.right);
                                  _moves++;
                                  _moveHistory.add('right');
                                  _checkAchievements();
                                });
                              }
                            },
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: 16,
                              itemBuilder: (context, index) {
                                int row = index ~/ 4;
                                int col = index % 4;
                                int value = grid[row][col];
                                
                                return Container(
                                  decoration: BoxDecoration(
                                    color: _getTileColor(value),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 2,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      value > 0 ? value.toString() : '',
                                      style: TextStyle(
                                        fontSize: value > 512 ? 20 : 24,
                                        fontWeight: FontWeight.bold,
                                        color: value <= 4 ? const Color(0xFF776E65) : Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF8F7A66),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTileColor(int value) {
    switch (value) {
      case 0:
        return const Color(0xFFCDC1B4);
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 16:
        return const Color(0xFFF59563);
      case 32:
        return const Color(0xFFF67C5F);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 256:
        return const Color(0xFFEDCC61);
      case 512:
        return const Color(0xFFEDC850);
      case 1024:
        return const Color(0xFFEDC53F);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFF3C3A32);
    }
  }

  // 显示教程
  void _showTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAF8EF),
        title: const Text('如何玩2048'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ListTile(
              leading: Icon(Icons.swipe),
              title: Text('滑动手指移动方块'),
            ),
            ListTile(
              leading: Icon(Icons.merge_type),
              title: Text('相同数字的方块相撞时会合并'),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline),
              title: Text('每次移动后会出现一个新的2或4'),
            ),
            ListTile(
              leading: Icon(Icons.flag),
              title: Text('尝试获得2048分！'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('开始游戏'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // 显示设置
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFAF8EF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 音频控制
              ListTile(
                leading: Icon(
                  _audioManager.isMuted ? Icons.volume_off : Icons.volume_up,
                ),
                title: const Text('声音'),
                trailing: Switch(
                  value: !_audioManager.isMuted,
                  onChanged: (value) {
                    setState(() {
                      _audioManager.toggleMute();
                    });
                  },
                ),
              ),
              if (!_audioManager.isMuted) ...[
                ListTile(
                  title: const Text('背景音乐音量'),
                  subtitle: Slider(
                    value: _audioManager.bgmVolume,
                    onChanged: (value) {
                      setState(() {
                        _audioManager.setBgmVolume(value);
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('音效音量'),
                  subtitle: Slider(
                    value: _audioManager.sfxVolume,
                    onChanged: (value) {
                      setState(() {
                        _audioManager.setSfxVolume(value);
                      });
                    },
                  ),
                ),
              ],
              const Divider(),
              // 其他设置选项
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('重置最高分'),
                onTap: () {
                  setState(() => bestScore = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('成就'),
                onTap: () {
                  Navigator.pop(context);
                  _showAchievementsDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于游戏'),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示关于对话框
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: '2048',
        applicationVersion: '1.0.0',
        applicationIcon: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFEDC22E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              '2048',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        children: const [
          Text('一个简单而有趣的数字游戏。'),
          SizedBox(height: 8),
          Text('滑动方块，相同数字合并，获得2048！'),
        ],
      ),
    );
  }

  // 撤销移动
  void _undoMove() {
    if (_canUndo) {
      setState(() {
        grid = List.generate(4, (i) => List.from(_previousGrid[i]));
        score = _previousScore;
        _canUndo = false;
        _usedUndo = true;
      });
      _saveGameData();
    }
  }

  // 保存状态用于撤销
  void _saveStateForUndo() {
    _previousGrid = List.generate(4, (i) => List.from(grid[i]));
    _previousScore = score;
    _canUndo = true;
  }

  /// Check for achievements and easter eggs
  Future<void> _checkAchievements() async {
    _gameTime = DateTime.now().difference(_gameStartTime);
    
    final newAchievements = await _achievementManager.checkAchievements(
      score: score,
      moves: _moves,
      gameTime: _gameTime,
      usedUndo: _usedUndo,
      grid: grid,
    );

    final newEasterEggs = await _achievementManager.checkEasterEggs(
      moveHistory: _moveHistory,
      grid: grid,
    );

    // Show achievement notifications
    for (String achievement in [...newAchievements, ...newEasterEggs]) {
      _showAchievementNotification(achievement);
      _audioManager.playAchievementSound();
    }
  }

  /// Show achievement notification
  void _showAchievementNotification(String achievement) {
    final descriptions = {
      ..._achievementManager.achievementDescriptions,
      ..._achievementManager.easterEggDescriptions,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Achievement Unlocked: ${descriptions[achievement]}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF776E65),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // 显示成就对话框
  void _showAchievementsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('成就'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._buildAchievementList(_achievementManager.achievementDescriptions),
              const Divider(height: 32),
              const Text(
                '彩蛋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildAchievementList(_achievementManager.easterEggDescriptions),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('关闭'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAchievementList(Map<String, String> achievements) {
    return achievements.entries.map((entry) {
      final bool isUnlocked = _achievementManager.isAchievementUnlocked(entry.key);
      return ListTile(
        leading: Icon(
          isUnlocked ? Icons.emoji_events : Icons.lock_outline,
          color: isUnlocked ? Colors.amber : Colors.grey,
        ),
        title: Text(
          entry.value,
          style: TextStyle(
            color: isUnlocked ? null : Colors.grey,
          ),
        ),
      );
    }).toList();
  }
}

/// 移动方向枚举
enum DragDirection {
  up,
  down,
  left,
  right,
}

/// 比较两个列表是否相等
/// [a] 第一个列表
/// [b] 第二个列表
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
} 