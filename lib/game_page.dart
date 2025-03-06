import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'audio_manager.dart';
import 'achievement_manager.dart';

/// 方块动画状态类
/// 用于记录和控制方块移动动画的状态
/// - fromX, fromY: 起始位置坐标
/// - toX, toY: 目标位置坐标
/// - value: 方块的数值
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
/// - 4x4网格布局：游戏主体为4x4的方块网格
/// - 上下左右滑动操作：通过手势控制方块移动
/// - 相同数字合并：相邻的相同数字会合并并翻倍
/// - 分数计算：合并时累加分数
/// - 游戏结束检测：无法移动时游戏结束
/// - 成就系统：完成特定目标获得成就
/// - 音效系统：移动、合并、游戏结束等音效
/// - 数据持久化：保存游戏进度和最高分
/// - 撤销功能：可以撤销上一步操作
/// - 自适应布局：适配不同屏幕尺寸
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  GamePageState createState() => GamePageState();
}

class GamePageState extends State<GamePage> with TickerProviderStateMixin {
  // 游戏核心数据
  List<List<int>> grid = List.generate(4, (_) => List.filled(4, 0)); // 4x4游戏网格
  int score = 0; // 当前游戏分数
  int bestScore = 0; // 历史最高分
  final Random random = Random(); // 随机数生成器，用于生成新的数字方块
  
  // 动画控制相关
  late AnimationController _slideController; // 滑动动画控制器
  late AnimationController _scaleController; // 缩放动画控制器
  late Animation<double> _scaleAnimation; // 缩放动画
  List<TileAnimation> _animations = []; // 方块动画列表
  bool _isAnimating = false; // 动画状态标志

  // 撤销功能相关
  List<List<int>> _previousGrid = []; // 上一步的网格状态
  int _previousScore = 0; // 上一步的分数
  bool _canUndo = false; // 是否可以撤销

  // 数据持久化键名
  static const String _keyBestScore = 'bestScore'; // 最高分存储键
  static const String _keyCurrentScore = 'currentScore'; // 当前分数存储键
  static const String _keyGrid = 'grid'; // 网格数据存储键

  // 游戏统计数据
  Duration _gameTime = Duration.zero; // 游戏时长
  int _moves = 0; // 移动次数
  List<String> _moveHistory = []; // 移动历史记录
  bool _usedUndo = false; // 是否使用过撤销
  late DateTime _gameStartTime; // 游戏开始时间

  // 功能管理器
  final AudioManager _audioManager = AudioManager(); // 音频管理器
  final AchievementManager _achievementManager = AchievementManager(); // 成就管理器

  /// 初始化状态
  /// 执行以下初始化操作：
  /// 1. 初始化动画控制器
  /// 2. 设置动画参数
  /// 3. 启动游戏初始化流程
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

  /// 初始化游戏系统
  /// 按顺序执行以下操作：
  /// 1. 初始化音频系统
  /// 2. 初始化成就系统
  /// 3. 加载保存的游戏数据
  /// 4. 记录游戏开始时间
  /// 5. 播放背景音乐
  Future<void> _initializeGame() async {
    await _audioManager.init();
    await _achievementManager.init();
    await _loadGameData();
    _gameStartTime = DateTime.now();
    _audioManager.playBackgroundMusic();
  }

  /// 释放资源
  /// 清理以下资源：
  /// 1. 滑动动画控制器
  /// 2. 缩放动画控制器
  /// 3. 音频管理器
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
  /// 执行以下操作：
  /// 1. 清空网格，重置为全0
  /// 2. 添加两个初始数字（2或4）
  /// 3. 保存初始状态到本地存储
  void initGame() {
    grid = List.generate(4, (_) => List.filled(4, 0));
    addNewTile();
    addNewTile();
    _saveGameData();
  }

  /// 在空位置添加新的数字
  /// 规则：
  /// - 在空白位置随机选择一个格子
  /// - 90%概率生成数字2
  /// - 10%概率生成数字4
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
  /// [direction] 移动方向（上下左右）
  /// 处理流程：
  /// 1. 保存移动前的状态用于检测变化
  /// 2. 根据方向执行具体的移动操作
  /// 3. 如果发生了移动，则：
  ///    - 添加新的数字
  ///    - 保存游戏状态
  ///    - 检查游戏是否结束
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

  /// 向左移动所有方块
  /// 处理流程：
  /// 1. 遍历每一行
  /// 2. 合并相同数字
  /// 3. 更新网格状态
  /// 4. 播放合并音效
  /// 返回是否发生了移动
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

  /// 向右移动所有方块
  /// 处理流程：
  /// 1. 遍历每一行
  /// 2. 反转行数据
  /// 3. 执行合并操作
  /// 4. 再次反转恢复顺序
  /// 5. 更新网格状态
  /// 6. 播放合并音效
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

  /// 向上移动所有方块
  /// 处理流程：
  /// 1. 遍历每一列
  /// 2. 提取列数据
  /// 3. 执行合并操作
  /// 4. 更新网格状态
  /// 5. 播放合并音效
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

  /// 向下移动所有方块
  /// 处理流程：
  /// 1. 遍历每一列
  /// 2. 提取并反转列数据
  /// 3. 执行合并操作
  /// 4. 反转回原始顺序
  /// 5. 更新网格状态
  /// 6. 播放合并音效
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showTutorial,
            tooltip: '游戏说明',
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undoMove : null,
            tooltip: '撤销',
          ),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: '设置',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxSize = constraints.maxWidth > 500 ? 500.0 : constraints.maxWidth;
            final padding = (constraints.maxWidth - maxSize) / 2;
            
            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxSize),
                padding: EdgeInsets.symmetric(horizontal: padding > 0 ? padding : 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // 分数显示
                    Row(
                      children: [
                        Expanded(child: _buildScoreBox('当前分数', score)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildScoreBox('最高分数', bestScore)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 游戏说明
                    Text(
                      '滑动手指合并相同的数字，努力达到2048！',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // 游戏网格
                    AspectRatio(
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建分数显示框
  /// [label] 分数标签文本
  /// [value] 分数值
  /// 返回一个带有阴影和圆角的容器，显示分数标签和数值
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

  /// 获取方块颜色
  /// [value] 方块的数值
  /// 根据方块数值返回对应的颜色：
  /// - 0: 空白格子颜色
  /// - 2-2048: 不同数值对应不同颜色
  /// - >2048: 默认深色
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

  /// 显示游戏教程对话框
  /// 包含以下内容：
  /// 1. 基本操作说明
  /// 2. 合并规则说明
  /// 3. 游戏目标说明
  /// 4. 开始游戏按钮
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

  /// 显示设置面板
  /// 包含以下设置项：
  /// 1. 音频控制
  ///    - 声音开关
  ///    - 背景音乐音量
  ///    - 音效音量
  /// 2. 游戏设置
  ///    - 重置最高分
  ///    - 查看成就
  ///    - 关于游戏
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

  /// 显示关于游戏对话框
  /// 展示以下信息：
  /// 1. 游戏名称和版本
  /// 2. 游戏图标
  /// 3. 游戏简介
  /// 4. 玩法说明
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

  /// 撤销上一步移动
  /// 执行以下操作：
  /// 1. 恢复上一步的网格状态
  /// 2. 恢复上一步的分数
  /// 3. 禁用撤销功能
  /// 4. 标记已使用撤销
  /// 5. 保存当前游戏状态
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

  /// 保存当前状态用于撤销
  /// 保存以下数据：
  /// 1. 当前网格状态的深拷贝
  /// 2. 当前分数
  /// 3. 启用撤销功能
  void _saveStateForUndo() {
    _previousGrid = List.generate(4, (i) => List.from(grid[i]));
    _previousScore = score;
    _canUndo = true;
  }

  /// 检查成就和彩蛋
  /// 处理流程：
  /// 1. 计算游戏时长
  /// 2. 检查常规成就
  /// 3. 检查特殊彩蛋
  /// 4. 显示成就通知
  /// 5. 播放成就音效
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

  /// 显示成就通知
  /// [achievement] 成就标识符
  /// 显示内容：
  /// 1. 成就图标
  /// 2. 成就描述
  /// 3. 动画效果
  /// 4. 自动消失
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

  /// 显示成就列表对话框
  /// 展示内容：
  /// 1. 已解锁的成就
  /// 2. 未解锁的成就
  /// 3. 特殊彩蛋
  /// 4. 成就图标和描述
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

  /// 构建成就列表项
  /// [achievements] 成就描述映射表
  /// 返回成就列表项组件：
  /// - 已解锁：金色奖杯图标
  /// - 未解锁：灰色锁定图标
  /// - 相应的成就描述文本
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