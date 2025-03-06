import 'package:flutter/material.dart';
import 'dart:math';

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

class GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  // 游戏网格，4x4的二维数组
  List<List<int>> grid = List.generate(4, (_) => List.filled(4, 0));
  // 当前游戏分数
  int score = 0;
  int bestScore = 0; // 新增：最高分
  // 随机数生成器
  final Random random = Random();
  
  // 新增：动画控制器
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    initGame();
  }

  @override
  void dispose() {
    _controller.dispose();
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
      backgroundColor: const Color(0xFFFAF8EF), // 米色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFAF8EF),
        title: const Text(
          '2048',
          style: TextStyle(
            color: Color(0xFF776E65),
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 分数面板
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildScoreBox('当前分数', score),
                  _buildScoreBox('最高分', bestScore),
                ],
              ),
              const SizedBox(height: 32),
              // 游戏说明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBADA0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '滑动方块，相同数字合并得到更大的数字！目标是获得2048！',
                  style: TextStyle(
                    color: Color(0xFF776E65),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              // 游戏主区域
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFBBADA0),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {},
                        onHorizontalDragUpdate: (details) {},
                        onVerticalDragEnd: (details) {
                          _handleDrag(details.primaryVelocity!, true);
                        },
                        onHorizontalDragEnd: (details) {
                          _handleDrag(details.primaryVelocity!, false);
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
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton('新游戏', Icons.refresh, () {
                    setState(() {
                      score = 0;
                      initGame();
                    });
                  }),
                  _buildControlButton('撤销', Icons.undo, () {
                    // TODO: 实现撤销功能
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 处理拖动手势
  void _handleDrag(double velocity, bool isVertical) {
    _controller.forward().then((_) => _controller.reverse());
    
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

  // 构建分数面板
  Widget _buildScoreBox(String title, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFBBADA0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 构建控制按钮
  Widget _buildControlButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8F7A66),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: value == 0
                  ? null
                  : Text(
                      value.toString(),
                      style: TextStyle(
                        color: value <= 4 ? const Color(0xFF776E65) : Colors.white,
                        fontSize: value < 100 ? 32 : value < 1000 ? 28 : 24,
                        fontWeight: FontWeight.bold,
                      ),
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