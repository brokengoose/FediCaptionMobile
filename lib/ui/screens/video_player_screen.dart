// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/accessibility_announcer.dart';
import '../../l10n/l10n.dart';

/// Full-screen accessible video player for Mastodon `video` and `gifv` media
/// attachments across Linux, macOS, Windows, iOS, and Android.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.altText,
    this.isGifv = false,
    this.controllerBuilder,
  });

  final String videoUrl;
  final String? altText;
  final bool isGifv;

  /// Optional controller factory for testing.
  final VideoPlayerController Function(Uri uri)? controllerBuilder;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _isMuted = false;
  String? _error;
  bool _invalidUrl = false;
  final FocusNode _rootFocus = FocusNode(debugLabel: 'VideoPlayerScreen');

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null || widget.videoUrl.trim().isEmpty) {
      // Runs synchronously from initState: no setState and no inherited-widget
      // lookups (context.l10n) here; build() localizes the message.
      _isInitializing = false;
      _invalidUrl = true;
      return;
    }

    final controller = widget.controllerBuilder != null
        ? widget.controllerBuilder!(uri)
        : VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onPlayerUpdate);

    try {
      await controller.initialize();
      await controller.setLooping(widget.isGifv);
      await controller.setVolume(widget.isGifv ? 0.0 : 1.0);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _isMuted = widget.isGifv;
        _isInitializing = false;
      });
      AccessibilityAnnouncer.announce(
        context.l10n.videoPlayerAnnouncePlayingVideo,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = context.l10n.videoPlayerError(e.toString());
      });
    }
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final err = _controller?.value.errorDescription;
    if (err != null && err.isNotEmpty && _error == null) {
      setState(() => _error = err);
      return;
    }
    setState(() {});
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final l10n = context.l10n;
    if (c.value.isPlaying) {
      await c.pause();
      AccessibilityAnnouncer.announce(l10n.videoPlayerAnnouncePaused);
    } else {
      if (c.value.position >= c.value.duration &&
          c.value.duration > Duration.zero) {
        await c.seekTo(Duration.zero);
      }
      await c.play();
      AccessibilityAnnouncer.announce(l10n.videoPlayerAnnouncePlaying);
    }
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final nextMuted = !_isMuted;
    await c.setVolume(nextMuted ? 0.0 : 1.0);
    if (!mounted) return;
    setState(() => _isMuted = nextMuted);
    final l10n = context.l10n;
    AccessibilityAnnouncer.announce(
      nextMuted
          ? l10n.videoPlayerAnnounceMuted
          : l10n.videoPlayerAnnounceUnmuted,
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const Duration _seekStep = Duration(seconds: 5);

  Duration _clampPosition(Duration target) {
    final duration = _controller?.value.duration ?? Duration.zero;
    if (target < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && target > duration) return duration;
    return target;
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.seekTo(_clampPosition(c.value.position + delta));
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Space toggles playback only when no control has focus; otherwise the
  /// focused button keeps its normal Space activation for keyboard users.
  KeyEventResult _handleRootKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        FocusManager.instance.primaryFocus == _rootFocus) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    // Left/Right seek from anywhere in the player: the visual scrubber is
    // pointer-only, so this is the keyboard equivalent.
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekBy(_seekStep);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBy(-_seekStep);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmedAlt = (widget.altText ?? '').trim();
    final c = _controller;
    final isReady = c != null && c.value.isInitialized;
    final isPlaying = isReady && c.value.isPlaying;

    final error = _invalidUrl ? l10n.videoPlayerInvalidUrl : _error;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        onKeyEvent: _handleRootKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: l10n.videoPlayerCloseTooltip,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.isGifv
                  ? l10n.videoPlayerTitleGifv
                  : l10n.videoPlayerTitleVideo,
            ),
            actions: [
              IconButton(
                tooltip: l10n.videoPlayerOpenBrowserTooltip,
                icon: const Icon(Icons.open_in_new),
                onPressed: _openInBrowser,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isInitializing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _openInBrowser,
                                  icon: const Icon(Icons.open_in_new),
                                  label: Text(
                                    l10n.videoPlayerOpenBrowserButton,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : isReady
                        ? GestureDetector(
                            onTap: _togglePlayPause,
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio > 0
                                    ? c.value.aspectRatio
                                    : 16 / 9,
                                child: VideoPlayer(c),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // Accessible playback controls bar
                if (isReady)
                  Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Screen-reader slider: swipe up/down (or increase/
                        // decrease actions) skips 5 seconds.
                        Semantics(
                          container: true,
                          slider: true,
                          label: l10n.videoPlayerSeekSemantics,
                          hint: l10n.videoPlayerSeekHint,
                          value: l10n.videoPlayerPositionValue(
                            _formatDuration(c.value.position),
                            _formatDuration(c.value.duration),
                          ),
                          increasedValue: l10n.videoPlayerPositionValue(
                            _formatDuration(
                              _clampPosition(c.value.position + _seekStep),
                            ),
                            _formatDuration(c.value.duration),
                          ),
                          decreasedValue: l10n.videoPlayerPositionValue(
                            _formatDuration(
                              _clampPosition(c.value.position - _seekStep),
                            ),
                            _formatDuration(c.value.duration),
                          ),
                          onIncrease: () => _seekBy(_seekStep),
                          onDecrease: () => _seekBy(-_seekStep),
                          excludeSemantics: true,
                          child: VideoProgressIndicator(
                            c,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            colors: VideoProgressColors(
                              playedColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: isPlaying
                                  ? l10n.videoPlayerPauseTooltip
                                  : l10n.videoPlayerPlayTooltip,
                              color: Colors.white,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              tooltip: _isMuted
                                  ? l10n.videoPlayerUnmuteTooltip
                                  : l10n.videoPlayerMuteTooltip,
                              color: Colors.white,
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                              ),
                              onPressed: _toggleMute,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatDuration(c.value.position)} / ${_formatDuration(c.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                if (trimmedAlt.isNotEmpty)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 130),
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        trimmedAlt,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
