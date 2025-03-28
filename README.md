# Flutter 2048 游戏

一个使用 Flutter 开发的现代化 2048 游戏，具有丰富的功能和优雅的界面设计。

## 功能特点

![demo](https://github.com/android-greenhand/fluttergame-2048/master/flutterdemo/output.gif)

### 核心游戏功能
- 经典的 4x4 游戏网格
- 流畅的滑动操作体验
- 智能的方块合并机制
- 实时分数计算
- 最高分记录


### 增强功能
- 成就系统
  - 多个解锁成就
  - 隐藏彩蛋
  - 实时成就提醒
- 音效系统
  - 背景音乐
  - 移动音效
  - 合并音效
  - 成就解锁音效
- 数据持久化
  - 自动保存游戏进度
  - 保存最高分记录
- 操作增强
  - 撤销功能
  - 重新开始
  - 游戏教程

### 界面设计
- 现代简约的界面风格
- 流畅的动画效果
- 自适应布局设计
- 优雅的配色方案

## 安装要求

- Flutter SDK 3.0.0 或更高版本
- Dart SDK 2.17.0 或更高版本
- Android Studio / VS Code
- Android SDK / Xcode（取决于目标平台）

## 开始使用

1. 克隆项目：
```bash
git clone [项目地址]
```

2. 安装依赖：
```bash
flutter pub get
```

3. 运行项目：
```bash
flutter run
```

## 游戏玩法

1. 基本规则：
   - 滑动手指移动方块
   - 相同数字的方块相撞时会合并
   - 每次移动后会出现一个新的 2 或 4
   - 努力达到 2048！

2. 操作方式：
   - 上滑：向上移动所有方块
   - 下滑：向下移动所有方块
   - 左滑：向左移动所有方块
   - 右滑：向右移动所有方块

3. 特殊功能：
   - 点击撤销按钮可以回退一步
   - 点击重新开始按钮可以重置游戏
   - 通过设置可以调整音效和音乐

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── game_page.dart         # 游戏主页面
├── audio_manager.dart     # 音频管理
└── achievement_manager.dart # 成就系统
```

## 技术特点

- 使用 Flutter 框架开发
- 采用 Provider 状态管理
- 实现数据持久化存储
- 优化的性能和内存管理
- 完善的错误处理机制

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进项目。

## 开源协议

本项目采用 MIT 协议开源。

## 致谢

- 感谢原版 2048 游戏的创意
- 感谢 Flutter 开源社区的支持
- 感谢所有贡献者的付出
