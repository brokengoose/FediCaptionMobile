// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/html_utils.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';

/// Renders Mastodon HTML or plain text with clickable, screen-reader-accessible
/// links, mentions, hashtags, and bare `http://`/`https://` URLs.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText.html(
    String htmlContent, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.mentions = const [],
    this.onTapMention,
    this.onTapUrl,
  }) : _content = htmlContent,
       _isHtml = true;

  const LinkifiedText.plain(
    String plainText, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onTapUrl,
  }) : _content = plainText,
       _isHtml = false,
       mentions = const [],
       onTapMention = null;

  final String _content;
  final bool _isHtml;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final List<MastodonMention> mentions;
  final void Function(MastodonMention mention)? onTapMention;
  final Future<void> Function(String url)? onTapUrl;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _createTapRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  Future<void> _openUrl(String url) async {
    if (widget.onTapUrl != null) {
      await widget.onTapUrl!(url);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyLarge;
    final scheme = Theme.of(context).colorScheme;
    final linkStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
      fontWeight: FontWeight.w500,
    );

    final l10n = context.l10n;
    final spans = widget._isHtml
        ? _parseHtmlToSpans(widget._content, baseStyle, linkStyle, l10n)
        : _linkifyPlainText(widget._content, baseStyle, linkStyle, l10n);

    // Trim leading/trailing empty newlines so cards stay tidy.
    final trimmedSpans = _trimBoundaryNewlines(spans);

    return Text.rich(
      TextSpan(style: baseStyle, children: trimmedSpans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  List<InlineSpan> _parseHtmlToSpans(
    String htmlContent,
    TextStyle? baseStyle,
    TextStyle linkStyle,
    AppLocalizations l10n,
  ) {
    if (htmlContent.trim().isEmpty) return const [];
    final document = html_parser.parseFragment(htmlContent);
    final spans = <InlineSpan>[];

    void walk(dom.Node node, TextStyle? currentStyle) {
      if (node is dom.Text) {
        final text = node.text;
        if (text.isEmpty) return;
        spans.addAll(_linkifyPlainText(text, currentStyle, linkStyle, l10n));
        return;
      }

      if (node is! dom.Element) return;
      final tag = node.localName?.toLowerCase() ?? '';
      final classes = node.classes;

      if (tag == 'br') {
        spans.add(const TextSpan(text: '\n'));
        return;
      }

      if (tag == 'a') {
        final href = (node.attributes['href'] ?? '').trim();
        final visibleText = _extractAnchorDisplayText(node);
        if (visibleText.isEmpty) return;

        if (href.isNotEmpty) {
          final isMention =
              classes.contains('mention') && !classes.contains('hashtag');
          final matchedMention = isMention ? _findMentionByUrl(href) : null;

          spans.add(
            TextSpan(
              text: visibleText,
              style: linkStyle,
              semanticsLabel: matchedMention != null
                  ? l10n.linkMentionSemantics(matchedMention.acct)
                  : l10n.linkUrlSemantics(visibleText),
              recognizer: _createTapRecognizer(() {
                if (matchedMention != null && widget.onTapMention != null) {
                  widget.onTapMention!(matchedMention);
                } else {
                  _openUrl(href);
                }
              }),
            ),
          );
          return;
        }
      }

      TextStyle? nextStyle = currentStyle;
      if (tag == 'strong' || tag == 'b') {
        nextStyle = (currentStyle ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
        );
      } else if (tag == 'em' || tag == 'i') {
        nextStyle = (currentStyle ?? const TextStyle()).copyWith(
          fontStyle: FontStyle.italic,
        );
      } else if (tag == 'code' || tag == 'pre') {
        nextStyle = (currentStyle ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
        );
      }

      final isBlock =
          tag == 'p' ||
          tag == 'div' ||
          tag == 'blockquote' ||
          tag == 'li' ||
          tag == 'pre';

      if (tag == 'li' && spans.isNotEmpty) {
        spans.add(const TextSpan(text: '\n• '));
      } else if (tag == 'li') {
        spans.add(const TextSpan(text: '• '));
      } else if (isBlock &&
          spans.isNotEmpty &&
          !_endsWithDoubleNewline(spans)) {
        spans.add(TextSpan(text: _endsWithNewline(spans) ? '\n' : '\n\n'));
      }

      for (final child in node.nodes) {
        walk(child, nextStyle);
      }
    }

    for (final child in document.nodes) {
      walk(child, baseStyle);
    }

    return spans;
  }

  /// Respects Mastodon's `.invisible` and `.ellipsis` span conventions so long
  /// URLs display cleanly while opening the full `href`.
  String _extractAnchorDisplayText(dom.Element anchor) {
    final buffer = StringBuffer();

    void visit(dom.Node node) {
      if (node is dom.Text) {
        buffer.write(node.text);
        return;
      }
      if (node is dom.Element) {
        if (node.classes.contains('invisible')) {
          return;
        }
        for (final child in node.nodes) {
          visit(child);
        }
        if (node.classes.contains('ellipsis')) {
          buffer.write('…');
        }
      }
    }

    for (final child in anchor.nodes) {
      visit(child);
    }

    final result = buffer.toString().trim();
    if (result.isNotEmpty) return result;
    return anchor.text.trim();
  }

  MastodonMention? _findMentionByUrl(String href) {
    for (final mention in widget.mentions) {
      if (mention.url == href) return mention;
    }
    return null;
  }

  List<InlineSpan> _linkifyPlainText(
    String text,
    TextStyle? currentStyle,
    TextStyle linkStyle,
    AppLocalizations l10n,
  ) {
    if (text.isEmpty) return const [];
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in HtmlUtils.urlRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: currentStyle,
          ),
        );
      }

      final (:url, :trailing) = HtmlUtils.splitTrailingUrlPunctuation(
        match.group(0) ?? '',
      );

      if (url.isNotEmpty) {
        spans.add(
          TextSpan(
            text: url,
            style: linkStyle,
            semanticsLabel: l10n.linkUrlSemantics(url),
            recognizer: _createTapRecognizer(() => _openUrl(url)),
          ),
        );
      }
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing, style: currentStyle));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: currentStyle));
    }

    return spans;
  }

  bool _endsWithNewline(List<InlineSpan> spans) {
    if (spans.isEmpty) return false;
    final last = spans.last;
    return last is TextSpan && (last.text?.endsWith('\n') ?? false);
  }

  bool _endsWithDoubleNewline(List<InlineSpan> spans) {
    if (spans.isEmpty) return false;
    final last = spans.last;
    return last is TextSpan && (last.text?.endsWith('\n\n') ?? false);
  }

  List<InlineSpan> _trimBoundaryNewlines(List<InlineSpan> spans) {
    final result = List<InlineSpan>.from(spans);
    while (result.isNotEmpty &&
        result.first is TextSpan &&
        (result.first as TextSpan).recognizer == null &&
        ((result.first as TextSpan).text ?? '').trim().isEmpty) {
      result.removeAt(0);
    }
    while (result.isNotEmpty &&
        result.last is TextSpan &&
        (result.last as TextSpan).recognizer == null &&
        ((result.last as TextSpan).text ?? '').trim().isEmpty) {
      result.removeLast();
    }
    return result;
  }
}
