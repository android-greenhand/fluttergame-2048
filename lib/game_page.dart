import 'package:flutter/material.dart';
import 'dart:math';

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
  int bestScore = 0; // 新增：最高分
  // 随机数生成器
  final Random random = Random();
  
  // 新增：动画相关变量
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  List<TileAnimation> _animations = [];
  bool _isAnimating = false;

  // 新增：历史记录，用于撤销功能
  List<List<int>> _previousGrid = [];
  int _previousScore = 0;
  bool _canUndo = false;

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
    initGame();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// 初始化游戏
  /// 清空网格并添加两个初始数字
  void initGame() {
    grid = List.generate(4, (_) => List.filled(4, 0));
    addNewTile();
    addNewTile();
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
        for (int i = 0; i < 4; i++) {
          grid[i][j] = newColumn[i];
        }
      }
    }
    return moved;
  }

  /// 向下移动
  bool moveDown() {
    bool moved = false;
    for (int j = 0; j < 4; j++) {
      // 获取每一列并反转，执行合并操作后再反转回来
      List<int> column = [grid[3][j], grid[2][j], grid[1][j], grid[0][j]];
      List<int> newColumn = mergeTiles(column);
      if (!listEquals(column, newColumn)) {
        moved = true;
        for (int i = 0; i < 4; i++) {
          grid[3-i][j] = newColumn[i];
        }
      }
    }
    return moved;
  }

  /// 合并相同数字的方块
  /// [line] 要合并的一行或一列数字
  /// 返回合并后的新数组
  List<int> mergeTiles(List<int> line) {
    List<int> newLine = List.filled(4, 0);
    int index = 0;
    
    // 移除所有0，只保留非0数字
    List<int> numbers = line.where((x) => x != 0).toList();
    
    // 合并相邻的相同数字
    for (int i = 0; i < numbers.length; i++) {
      if (i + 1 < numbers.length && numbers[i] == numbers[i + 1]) {
        // 相同数字合并，分数增加
        newLine[index] = numbers[i] * 2;
        score += numbers[i] * 2;
        i++; // 跳过下一个数字
      } else {
        newLine[index] = numbers[i];
      }
      index++;
    }
    
    return newLine;
  }

  /// 检查游戏是否结束
  /// 当没有空格且没有可以合并的相邻数字时，游戏结束
  bool isGameOver() {
    // 检查是否有空格
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) return false;
      }
    }

    // 检查是否有可以合并的相邻数字
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        // 检查水平方向
        if (grid[i][j] == grid[i][j + 1]) return false;
        // 检查垂直方向
        if (grid[j][i] == grid[j + 1][i]) return false;
      }
    }

    return true;
  }

  /// 显示游戏结束对话框
  void showGameOverDialog() {
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
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  if (score > bestScore) {
                    bestScore = score;
                  }
                  score = 0;
                  _canUndo = false;
                  initGame();
                });
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildScorePanel(),
                    const SizedBox(height: 32),
                    _buildGameBoard(),
                    const SizedBox(height: 32),
                    _buildControlPanel(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '2048',
                style: TextStyle(
                  color: Color(0xFF776E65),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '合并相同数字，获得2048！',
                style: TextStyle(
                  color: Color(0xFF776E65),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.help_outline, color: Color(0xFF776E65)),
                onPressed: _showTutorial,
                tooltip: '游戏说明',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF776E65)),
                onPressed: _showSettings,
                tooltip: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建分数面板
  Widget _buildScorePanel() {
    return Row(
      children: [
        Expanded(
          child: _buildScoreBox(
            '当前分数',
            score,
            hasAnimation: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildScoreBox('最高分', bestScore),
        ),
      ],
    );
  }

  // 构建分数盒子
  Widget _buildScoreBox(String title, int value, {bool hasAnimation = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFBBADA0),
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
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: Text(
              value.toString(),
              key: ValueKey<int>(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建游戏面板
  Widget _buildGameBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFBBADA0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (!_isAnimating) {
              _handleDrag(details.primaryVelocity!, true);
            }
          },
          onHorizontalDragEnd: (details) {
            if (!_isAnimating) {
              _handleDrag(details.primaryVelocity!, false);
            }
          },
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: 16,
            itemBuilder: _buildGridTile,
          ),
        ),
      ),
    );
  }

  // 构建控制面板
  Widget _buildControlPanel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          '新游戏',
          Icons.refresh,
          _startNewGame,
          const Color(0xFF8F7A66),
        ),
        _buildControlButton(
          '撤销',
          Icons.undo,
          _canUndo ? _undoMove : null,
          const Color(0xFFBBADA0),
        ),
      ],
    );
  }

  // 构建控制按钮
  Widget _buildControlButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
    );
  }

  // 构建网格方块
  Widget _buildGridTile(BuildContext context, int index) {
    int row = index ~/ 4;
    int col = index % 4;
    int value = grid[row][col];
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: _getTileBackgroundColor(value),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (value > 0)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Center(
              child: value == 0
                  ? null
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: value <= 4 ? const Color(0xFF776E65) : Colors.white,
                        fontSize: value < 100 ? 32 : value < 1000 ? 28 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text(value.toString()),
                    ),
            ),
          ),
        );
      },
    );
  }

  // 获取方块背景颜色
  Color _getTileBackgroundColor(int value) {
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
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('重置最高分'),
              onTap: () {
                setState(() => bestScore = 0);
                Navigator.pop(context);
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

  // 开始新游戏
  void _startNewGame() {
    if (score > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('开始新游戏'),
          content: const Text('确定要放弃当前游戏开始新游戏吗？'),
          actions: [
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  if (score > bestScore) {
                    bestScore = score;
                  }
                  score = 0;
                  _canUndo = false;
                  initGame();
                });
              },
            ),
          ],
        ),
      );
    } else {
      setState(() {
        initGame();
      });
    }
  }

  // 撤销移动
  void _undoMove() {
    if (_canUndo) {
      setState(() {
        grid = List.generate(4, (i) => List.from(_previousGrid[i]));
        score = _previousScore;
        _canUndo = false;
      });
    }
  }

  // 处理拖动
  void _handleDrag(double velocity, bool isVertical) {
    _scaleController.forward().then((_) => _scaleController.reverse());
    
    // 保存当前状态用于撤销
    _previousGrid = List.generate(4, (i) => List.from(grid[i]));
    _previousScore = score;
    _canUndo = true;

    setState(() {
      if (isVertical) {
        if (velocity < 0) {
          move(DragDirection.up);
        } else {
          move(DragDirection.down);
        }
      } else {
        if (velocity < 0) {
          move(DragDirection.left);
        } else {
          move(DragDirection.right);
        }
      }
    });
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