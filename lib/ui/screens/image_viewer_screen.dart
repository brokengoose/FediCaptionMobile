// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

/// Full-screen image viewer that displays the entire image scaled to fit the
/// viewport (`BoxFit.contain`) with pinch-to-zoom and accessible controls.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.altText,
  });

  final String imageUrl;
  final String? altText;

  @override
  Widget build(BuildContext context) {
    final trimmedAlt = (altText ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close full-screen image',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Full Image'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                image: true,
                label: trimmedAlt.isNotEmpty
                    ? 'Full image: $trimmedAlt'
                    : 'Full image with no alt text provided.',
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: SizedBox.expand(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Could not load full image.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
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
