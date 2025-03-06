import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 管理游戏中所有音频相关功能的类
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  /// 背景音乐播放器
  final AudioPlayer _bgmPlayer = AudioPlayer();
  
  /// 音效播放器
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  /// 是否静音
  bool _isMuted = true; // 默认静音
  
  /// 背景音乐音量
  double _bgmVolume = 0.5;
  
  /// 音效音量
  double _sfxVolume = 0.7;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 音频文件网络地址
  static const Map<String, String> _audioUrls = {
    'background': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'merge': 'https://www.soundjay.com/button/button-09.mp3',
    'move': 'https://www.soundjay.com/button/button-07.mp3',
    'game_over': 'https://www.soundjay.com/button/button-10.mp3',
    'achievement': 'https://www.soundjay.com/button/button-08.mp3',
  };

  /// 缓存的音频文件路径
  final Map<String, String> _cachedFiles = {};

  /// 初始化音频设置
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_bgmVolume);
      await _sfxPlayer.setVolume(_sfxVolume);
      
      // 设置为已初始化，即使没有音频文件也允许游戏继续
      _isInitialized = true;
    } catch (e) {
      debugPrint('初始化音频管理器时出错: $e');
      // 即使出错也设置为已初始化
      _isInitialized = true;
    }
  }

  /// 预加载所有音频文件
  Future<void> _preloadAudio() async {
    // 暂时不加载音频文件
    return;
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('Web平台不支持文件缓存');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return cacheDir;
    } catch (e) {
      debugPrint('获取缓存目录时出错: $e');
      rethrow;
    }
  }

  /// 播放背景音乐
  Future<void> playBackgroundMusic() async {
    if (_isMuted || !_isInitialized) return;
    
    try {
      final audioPath = _cachedFiles['background'];
      if (audioPath != null) {
        await _bgmPlayer.stop();
        await _bgmPlayer.play(DeviceFileSource(audioPath));
      }
    } catch (e) {
      debugPrint('播放背景音乐时出错: $e');
    }
  }

  /// 播放合并音效
  Future<void> playMergeSound() async {
    if (_isMuted || !_isInitialized) return;
    await _playSoundEffect('merge');
  }

  /// 播放移动音效
  Future<void> playMoveSound() async {
    if (_isMuted || !_isInitialized) return;
    await _playSoundEffect('move');
  }

  /// 播放游戏结束音效
  Future<void> playGameOverSound() async {
    if (_isMuted || !_isInitialized) return;
    await _playSoundEffect('game_over');
  }

  /// 播放成就解锁音效
  Future<void> playAchievementSound() async {
    if (_isMuted || !_isInitialized) return;
    await _playSoundEffect('achievement');
  }

  /// 播放音效的通用方法
  Future<void> _playSoundEffect(String soundName) async {
    if (_isMuted || !_isInitialized) return;
    
    try {
      final audioPath = _cachedFiles[soundName];
      if (audioPath != null) {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(DeviceFileSource(audioPath));
      }
    } catch (e) {
      debugPrint('播放音效时出错: $e');
    }
  }

  /// 切换静音状态
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _bgmPlayer.pause();
    } else {
      playBackgroundMusic();
    }
  }

  /// 设置背景音乐音量
  void setBgmVolume(double volume) {
    _bgmVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer.setVolume(_bgmVolume);
  }

  /// 设置音效音量
  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _sfxPlayer.setVolume(_sfxVolume);
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      if (kIsWeb) return;

      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      _cachedFiles.clear();
      _isInitialized = false;
      debugPrint('音频缓存已清理');
    } catch (e) {
      debugPrint('清理音频缓存时出错: $e');
    }
  }

  /// 释放音频播放器资源
  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();
      await _sfxPlayer.dispose();
      _isInitialized = false;
    } catch (e) {
      debugPrint('释放音频资源时出错: $e');
    }
  }

  /// 获取静音状态
  bool get isMuted => _isMuted;

  /// 获取背景音乐音量
  double get bgmVolume => _bgmVolume;

  /// 获取音效音量
  double get sfxVolume => _sfxVolume;

  /// 获取初始化状态
  bool get isInitialized => _isInitialized;
} 