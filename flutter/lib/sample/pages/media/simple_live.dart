// ignore_for_file: non_constant_identifier_names
part of '../rapid_kit_sample_pages.dart';

/// 一个简单的直播播放页面
class SimpleLivePage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String? deviceAbilities;

  const SimpleLivePage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.deviceAbilities,
  });

  @override
  State<SimpleLivePage> createState() => _SimpleLivePageState();
}

class _SimpleLivePageState extends LifecycleAwareState<SimpleLivePage> {
  late String _deviceId;
  late String _deviceName;

  /// P2P连接实例
  late Pipe _pipe;

  /// 负责直播流的获取
  late LiveStream _liveStream;

  /// 播放器，负责音视频解码、缓冲管理、音画同步、渲染输出
  late Player _player;

  bool _rendering = false;
  bool _establishFailed = false;
  bool _closing = false;
  bool _resume_pending = false;
  Future<void>? _stop_operation;
  double _displayWidth = 320;
  double _displayHeight = 180;

  @override
  Widget build(BuildContext context) => _scaffold(
      _deviceName.isEmpty ? _deviceId : _deviceName,
      context,
      _buildContent(),
      _deviceId,
      _deviceName);

  Widget _buildContent() => Container(
        color: SampleThemeConfigure.colorVideoBackground,
        child: _buildPlayer(),
      );

  Widget _buildPlayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(1.0, constraints.maxWidth);
        final maxHeight = math.max(1.0, constraints.maxHeight - 180);
        final width = math.min(_displayWidth, maxWidth);
        final height = math.min(_displayHeight, maxHeight);
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _player.texture(),
                    ),
                  ),
                  if (!_rendering && !_establishFailed) createBufferingWidget(),
                  if (_establishFailed) _establishFailedWidget(),
                ],
              ),
            ),
            ColoredBox(
              color: SampleThemeConfigure.colorBackground,
              child: Column(
                children: [
                  Text('拉伸铺满 · ${width.round()} × ${height.round()}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in const <String, Size>{
                        '16:9': Size(320, 180),
                        '4:3': Size(320, 240),
                        '1:1': Size(320, 320),
                      }.entries)
                        ChoiceChip(
                          label: Text(preset.key),
                          selected: (width / height -
                                      preset.value.width / preset.value.height)
                                  .abs() <
                              0.01,
                          onSelected: (_) => setState(() {
                            _displayWidth = preset.value.width;
                            _displayHeight = preset.value.height;
                          }),
                        ),
                    ],
                  ),
                  Row(children: [
                    const SizedBox(width: 40, child: Text('宽')),
                    Expanded(
                      child: Slider(
                        value: width,
                        min: 1,
                        max: maxWidth,
                        onChanged: (value) => setState(() => _displayWidth = value),
                      ),
                    ),
                  ]),
                  Row(children: [
                    const SizedBox(width: 40, child: Text('高')),
                    Expanded(
                      child: Slider(
                        value: height,
                        min: 1,
                        max: maxHeight,
                        onChanged: (value) => setState(() => _displayHeight = value),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _establishFailedWidget() {
    return EstablishFailedWidget(
      onRetry: () {
        // 点击后，走统一恢复入口，避免只重连不恢复播放
        start();
        setState(() => _establishFailed = false);
      },
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _deviceId = widget.deviceId;
    _deviceName = widget.deviceName;

    /// 初始化三大核心模块
    _prepareComponents();
  }

  /// 页面可见时启动播放
  @override
  void start() {
    if (_closing) return;
    if (_stop_operation != null) {
      if (!_resume_pending) {
        _resume_pending = true;
        unawaited(_resume_after_stop(_stop_operation!));
      }
      return;
    }
    // 恢复时尝试重新建立连接（P2P 可能会由于处于后台等原因被系统断开）
    if (!_pipe.isEstablished) {
      _pipe.establish();
    }
    _liveStream.start();
    _player.start();
  }

  /// 页面不可见时停止播放
  @override
  void stop() {
    _stop_operation ??= _stop_playback();
    unawaited(_stop_operation!.catchError((Object error, StackTrace stack) {
      Logging.e('SimpleLivePage', '[stop] failed: $error\n$stack');
    }));
  }

  Future<void> _stop_playback() async {
    try {
      await _player.stop_async();
      await _liveStream.stop_async();
    } finally {
      _stop_operation = null;
    }
  }

  Future<void> _resume_after_stop(Future<void> stop_operation) async {
    try {
      await stop_operation;
      _resume_pending = false;
      if (mounted && !_closing && isResumed) start();
    } catch (error, stack) {
      _resume_pending = false;
      Logging.e('SimpleLivePage', '[resume_after_stop] failed: $error\n$stack');
    }
  }

  Future<void> _close_session() async {
    try {
      await (_stop_operation ?? _stop_playback());
      await _player.destroy_async();
      await _liveStream.destroy_async();
      await _pipe.abolish_async();
      await _pipe.destroy_async();
    } catch (error, stack) {
      Logging.e('SimpleLivePage', '[close_session] failed: $error\n$stack');
    }
  }

  /// 退出页面的时候，销毁清理资源
  @override
  void dispose() {
    _closing = true;
    unawaited(_close_session());
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _prepareComponents() async {
    // 1. 初始化 P2P
    _pipe = Pipe.create(_deviceId);
    // IMPORTANT: Only use TCP mode (1) when remote device explicitly supports it and there is a clear requirement
    _pipe.setTransportMode(SampleConstants.tgrtcTcpModeEnabled ? 1 : 0);
    _pipe.listen((state) {
      if (!mounted || _closing) return;
      if (state == PipeState.established) {
        // 连接建立成功，可在此发送指令等
      } else if (state == PipeState.failed) {
        // 连接失败，可在此进行提示或者发起重试
        setState(() => _establishFailed = true);
      } else {
        // 其他状态（连接中、断开等）
        setState(() {
          _establishFailed = false;
          _rendering = false;
        });
      }
    });

    // 2. 初始化 LiveStream
    final streamAudioEnabled =
        DeviceAudioCapability.streamAudioEnabledFromDeviceAbilities(
            widget.deviceAbilities);
    _liveStream =
        LiveStream.createPrimary(_pipe, enableAudio: streamAudioEnabled);
    _liveStream.enableDebugging(SampleConstants.streamDebuggingEnabled);

    // 按需设置清晰度，如 高清
    _liveStream.highQuality();

    // 3. 初始化 Player
    _player = _createSamplePlayer(live: true);
    _player.setVideoScalingMode(VideoScalingMode.stretch);
    _player.onRenderState = (state) {
      if (!mounted || _closing) return;
      setState(() => _rendering = state != RenderState.buffering);
    };

    // 4. 准备播放器 - 建立 LiveStream 和 Player 的联系
    final provider = _liveStream.provider();
    if (provider != null) {
      await _player.prepare(provider);
    }
  }
}
