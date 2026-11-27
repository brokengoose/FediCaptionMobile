// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/accessibility_announcer.dart';
import '../../l10n/l10n.dart';
import '../../services/media_cache_service.dart';
import '../widgets/cached_network_image_provider.dart';

/// Full-screen image viewer that displays the entire image scaled to fit the
/// viewport (`BoxFit.contain`) with pinch-to-zoom, accessible controls, and
/// long-press (plus AppBar button) native OS sharing to save or share the image.
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.altText,
    this.onShareImage,
  });

  final String imageUrl;
  final String? altText;

  /// Optional custom share callback (primarily for testing).
  final Future<void> Function(String imageUrl, Rect? shareOrigin)? onShareImage;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return true;
    }
    return false;
  }

  Future<void> _handleShare({Offset? globalPosition}) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final l10n = context.l10n;

    try {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      final origin = _resolveShareOrigin(globalPosition);

      if (widget.onShareImage != null) {
        await widget.onShareImage!(widget.imageUrl, origin);
        return;
      }

      final uri = Uri.tryParse(widget.imageUrl);
      if (uri == null) {
        throw StateError(l10n.imageViewerInvalidUrl);
      }

      final cached = await MediaCacheService.instance.getOrFetch(
        widget.imageUrl,
      );
      final mimeType = cached.mimeType;
      final fileName = _deriveFileName(uri, mimeType);

      AccessibilityAnnouncer.announce(l10n.imageViewerAnnounceShare);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(cached.bytes, mimeType: mimeType)],
          fileNameOverrides: [fileName],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.imageViewerShareError(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Rect? _resolveShareOrigin(Offset? globalPosition) {
    if (globalPosition != null) {
      return Rect.fromCenter(center: globalPosition, width: 1, height: 1);
    }
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    return null;
  }

  String _deriveFileName(Uri uri, String mimeType) {
    final lastSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.trim()
        : '';
    if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
      return lastSegment;
    }
    final ext = switch (mimeType.toLowerCase()) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    return 'fedicaption_image.$ext';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trimmedAlt = (widget.altText ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.imageViewerCloseTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.imageViewerTitle),
        actions: [
          IconButton(
            tooltip: l10n.imageViewerShareTooltip,
            onPressed: _isSharing ? null : () => _handleShare(),
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                image: true,
                label: trimmedAlt.isNotEmpty
                    ? l10n.imageViewerWithAltSemantics(trimmedAlt)
                    : l10n.imageViewerNoAltSemantics,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (details) =>
                        _handleShare(globalPosition: details.globalPosition),
                    onSecondaryTapUp: (details) =>
                        _handleShare(globalPosition: details.globalPosition),
                    child: SizedBox.expand(
                      child: Image(
                        image: DiskCachedNetworkImage(widget.imageUrl),
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.white70,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.imageViewerLoadError,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (trimmedAlt.isNotEmpty)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 140),
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
    );
  }
}
