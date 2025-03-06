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

class GamePageState extends State<GamePage> {
  // 游戏网格，4x4的二维数组
  List<List<int>> grid = List.generate(4, (_) => List.filled(4, 0));
  // 当前游戏分数
  int score = 0;
  // 随机数生成器
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    initGame();
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
          title: const Text('游戏结束'),
          content: Text('最终得分: $score'),
          actions: <Widget>[
            TextButton(
              child: const Text('重新开始'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  score = 0;
                  initGame();
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2048'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                score = 0;
                initGame();
              });
            },
            child: const Text('新游戏', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 计算游戏区域的大小，保持正方形
          double gameSize = constraints.maxWidth > constraints.maxHeight ? 
                          constraints.maxHeight * 0.7 : constraints.maxWidth * 0.9;
          
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(), // 禁用滚动，防止与游戏手势冲突
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // 显示当前分数
                  Text(
                    '得分: $score',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // 游戏主区域
                  SizedBox(
                    width: gameSize,
                    height: gameSize,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque, // 确保空白区域也能检测手势
                      onVerticalDragUpdate: (details) {}, // 添加空的更新回调以确保垂直拖动被识别
                      onHorizontalDragUpdate: (details) {}, // 添加空的更新回调以确保水平拖动被识别
                      // 处理垂直滑动
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < 0) {
                            setState(() {
                              move(DragDirection.up);
                            });
                          } else {
                            setState(() {
                              move(DragDirection.down);
                            });
                          }
                        }
                      },
                      // 处理水平滑动
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! < 0) {
                            setState(() {
                              move(DragDirection.left);
                            });
                          } else {
                            setState(() {
                              move(DragDirection.right);
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // 4x4网格
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: 16,
                          itemBuilder: (context, index) {
                            int row = index ~/ 4;
                            int col = index % 4;
                            int value = grid[row][col];
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: getTileColor(value),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      value == 0 ? '' : value.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: value <= 4 ? Colors.grey[800] : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 根据数字获取对应的颜色
  /// [value] 方块上的数字
  Color getTileColor(int value) {
    switch (value) {
      case 0: return Colors.grey[200]!;
      case 2: return Colors.blue[100]!;
      case 4: return Colors.blue[200]!;
      case 8: return Colors.blue[300]!;
      case 16: return Colors.blue[400]!;
      case 32: return Colors.blue[500]!;
      case 64: return Colors.blue[600]!;
      case 128: return Colors.blue[700]!;
      case 256: return Colors.blue[800]!;
      case 512: return Colors.blue[900]!;
      default: return Colors.blue[900]!;
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