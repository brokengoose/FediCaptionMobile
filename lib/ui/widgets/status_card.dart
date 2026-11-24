// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../../core/accessibility_announcer.dart';
import '../../core/constants.dart';
import '../../core/html_utils.dart';
import '../../core/language/language_registry.dart';
import '../../core/post_read_aloud_builder.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time_utils.dart';
import '../../l10n/l10n.dart';
import '../../models/mastodon_models.dart';
import '../../services/translation_service.dart';
import '../../state/app_controller.dart';
import 'accessible_tip.dart';
import 'linkified_text.dart';
import 'media_attachment_card.dart';
import 'post_translation_banner.dart';
import 'quoted_status_card.dart';
import 'status_header_parts.dart';

/// Accessible Mastodon status card supporting:
/// - Clickable user avatar, display name, and handle (including boost banner)
/// - Clickable relative timestamp permalink in the upper-right corner
/// - Embedded `RE: <url>` / native quoted post window displayed above the reply
/// - On-demand AI alt-text description & Read Aloud on media
/// - Reply, Boost, Favorite, Bookmark, Thread, Edit (own posts), and Delete (own posts)
class StatusCard extends StatefulWidget {
  const StatusCard({
    super.key,
    required this.status,
    required this.app,
    required this.onOpenProfile,
    required this.onOpenThread,
    required this.onReply,
    required this.onToggleBoost,
    required this.onToggleFavorite,
    required this.onToggleBookmark,
    this.onEdit,
    this.onDelete,
    this.enableTranslationOffer = false,
    this.enableReadAloud = false,
    this.isKeyboardSelected = false,
    this.cwRevealedOverride,
    this.onToggleCw,
  });

  final MastodonStatus status;
  final AppController app;
  final void Function(MastodonAccount account) onOpenProfile;
  final void Function(MastodonStatus status) onOpenThread;
  final void Function(MastodonStatus status) onReply;
  final Future<void> Function(MastodonStatus status) onToggleBoost;
  final Future<void> Function(MastodonStatus status) onToggleFavorite;
  final Future<void> Function(MastodonStatus status) onToggleBookmark;
  final void Function(MastodonStatus status)? onEdit;
  final Future<void> Function(MastodonStatus status)? onDelete;

  /// When true (e.g. for an opened post in `ThreadScreen`), checks the post's
  /// language against the user's OS language and offers on-device translation
  /// at the top of the post when they differ.
  final bool enableTranslationOffer;

  /// When true (e.g. for an opened post in `ThreadScreen`), renders a
  /// "Read Aloud" button at the top of the post that reads the post and all
  /// of its alt-text via TTS.
  final bool enableReadAloud;

  /// Highlights this card with a primary focus border when navigated to via
  /// keyboard shortcuts (`j`/`k` or arrow keys).
  final bool isKeyboardSelected;

  /// Optional external Content Warning revealed state (allows `x` shortcut).
  final bool? cwRevealedOverride;

  /// Optional callback invoked when toggling Content Warning.
  final VoidCallback? onToggleCw;

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard> {
  bool _cwRevealed = false;
  LeadingQuoteMatch? _leadingQuote;

  String? _detectedLanguage;
  String? _osLanguage;
  bool _canOfferTranslation = false;
  bool _isTranslating = false;
  bool _showingTranslation = false;
  PostTranslationResult? _translationResult;
  String? _translationError;

  String get _postTtsKey => 'post_full_${widget.status.displayStatus.id}';

  @override
  void initState() {
    super.initState();
    _syncQuoteResolution();
    if (widget.enableTranslationOffer) {
      _checkTranslationOffer();
    }
  }

  @override
  void dispose() {
    if (widget.enableReadAloud && widget.app.tts.isSpeakingKey(_postTtsKey)) {
      widget.app.tts.stop().catchError((_) {});
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final statusChanged =
        oldWidget.status.displayStatus.id != widget.status.displayStatus.id ||
            oldWidget.status.displayStatus.contentHtml !=
                widget.status.displayStatus.contentHtml;
    if (oldWidget.status.displayStatus.id != widget.status.displayStatus.id ||
        (oldWidget.enableReadAloud && !widget.enableReadAloud)) {
      final oldKey = 'post_full_${oldWidget.status.displayStatus.id}';
      if (widget.app.tts.isSpeakingKey(oldKey)) {
        widget.app.tts.stop().catchError((_) {});
      }
    }
    if (statusChanged) {
      _syncQuoteResolution();
    }
    if (statusChanged ||
        oldWidget.enableTranslationOffer != widget.enableTranslationOffer) {
      _detectedLanguage = null;
      _osLanguage = null;
      _canOfferTranslation = false;
      _isTranslating = false;
      _showingTranslation = false;
      _translationResult = null;
      _translationError = null;
      if (widget.enableTranslationOffer) {
        _checkTranslationOffer();
      }
    }
  }

  String _translatableBodyPlainText() {
    final target = widget.status.displayStatus;
    final bodyHtml =
        _leadingQuote != null ? _leadingQuote!.remainingHtml : target.contentHtml;
    return HtmlUtils.htmlToPlainText(bodyHtml).trim();
  }

  Future<void> _checkTranslationOffer() async {
    final target = widget.status.displayStatus;
    final bodyText = _translatableBodyPlainText();
    final combinedText = [
      if (target.spoilerText.trim().isNotEmpty) target.spoilerText.trim(),
      if (bodyText.isNotEmpty) bodyText,
      for (final media in target.mediaAttachments)
        if (media.hasAltText) media.description!.trim(),
    ].join('\n');
    if (combinedText.isEmpty) return;

    final translation = widget.app.translation;
    final supported = await translation.isTranslationSupported(
      settings: widget.app.settings,
      credentials: widget.app.credentials,
      session: widget.app.session,
      instanceLimits: widget.app.instanceLimits,
    );
    if (!mounted || !supported) return;

    final detected = await translation.detectPostLanguage(
      declaredLanguage: target.language,
      plainText: combinedText,
    );
    if (!mounted || detected == null) return;

    final osLang = translation.currentOsLanguageCode();
    if (detected == osLang) return;

    setState(() {
      _detectedLanguage = detected;
      _osLanguage = osLang;
      _canOfferTranslation = true;
    });
  }

  Future<void> _handleTranslate() async {
    final sourceLang = _detectedLanguage;
    final targetLang = _osLanguage;
    if (_isTranslating || sourceLang == null || targetLang == null) return;

    final target = widget.status.displayStatus;
    final bodyText = _translatableBodyPlainText();
    final spoiler = target.spoilerText.trim();
    final altTexts = <String, String>{
      for (final media in target.mediaAttachments)
        if (media.hasAltText) media.id: media.description!.trim(),
    };

    final l10n = context.l10n;
    setState(() {
      _isTranslating = true;
      _translationError = null;
    });

    try {
      final result = await widget.app.translation.translatePost(
        text: bodyText,
        spoilerText: spoiler.isEmpty ? null : spoiler,
        altTexts: altTexts,
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
        statusId: target.id,
        settings: widget.app.settings,
        credentials: widget.app.credentials,
        session: widget.app.session,
        instanceLimits: widget.app.instanceLimits,
      );
      if (!mounted) return;
      _stopReadAloudIfActive();
      setState(() {
        _translationResult = result;
        _showingTranslation = true;
        _isTranslating = false;
      });
      AccessibilityAnnouncer.announce(
        l10n.statusAnnounceTranslated(
          TranslationService.languageDisplayName(targetLang),
          result.engineName,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translationError = e.toString().replaceFirst('Bad state: ', '');
        _isTranslating = false;
      });
    }
  }

  void _stopReadAloudIfActive() {
    if (widget.app.tts.isSpeakingKey(_postTtsKey)) {
      widget.app.tts.stop().catchError((_) {});
    }
  }

  String _buildPostReadAloudText(AppLocalizations l10n) {
    final target = widget.status.displayStatus;
    final quoteUrl = _leadingQuote?.quoteUrl;
    final embeddedQuote = target.quotedStatus ??
        (quoteUrl != null ? widget.app.cachedQuotedStatus(quoteUrl) : null);
    final translation = _showingTranslation ? _translationResult : null;

    return PostReadAloudBuilder.build(
      status: target,
      l10n: l10n,
      bodyOverride: (translation?.translatedText ?? '').trim().isNotEmpty
          ? translation!.translatedText
          : null,
      spoilerOverride: (translation?.translatedSpoiler ?? '').trim().isNotEmpty
          ? translation!.translatedSpoiler
          : null,
      translatedAltTexts: translation?.translatedAltTexts ?? const {},
      aiAltTextLookup: widget.app.aiDescriptionForMedia,
      embeddedQuote: embeddedQuote,
    );
  }

  String _resolveReadAloudLanguage() {
    if (_showingTranslation && _translationResult != null) {
      return _translationResult!.targetLanguage;
    }
    return LanguageRegistry.resolveCode(_detectedLanguage) ??
        LanguageRegistry.resolveCode(widget.status.displayStatus.language) ??
        widget.app.settings.language;
  }

  void _syncQuoteResolution() {
    final target = widget.status.displayStatus;
    _leadingQuote = HtmlUtils.extractLeadingQuote(target.contentHtml);
    final quoteUrl = _leadingQuote?.quoteUrl;
    if (target.quotedStatus == null &&
        quoteUrl != null &&
        !widget.app.hasResolvedQuote(quoteUrl) &&
        !widget.app.isResolvingQuote(quoteUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.app.resolveQuotedStatus(quoteUrl);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.status;
    final target = outer.displayStatus;
    final isOwnPost = widget.app.currentAccount?.id == target.account.id;
    final scheme = Theme.of(context).colorScheme;
    final fedi = context.fediColors;
    final l10n = context.l10n;
    final hasCw = target.spoilerText.trim().isNotEmpty;
    final cwRevealed = widget.cwRevealedOverride ?? _cwRevealed;

    return Card(
      shape: widget.isKeyboardSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: scheme.primary,
                width: 2.5,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Boost banner (clickable booster profile)
            if (outer.isBoost)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  button: true,
                  label: l10n.statusBoostedSemantics(
                    outer.account.effectiveDisplayName,
                  ),
                  child: AccessibleTip(
                    message: l10n.statusBoostedTip(
                      outer.account.effectiveDisplayName,
                    ),
                    child: InkWell(
                      onTap: () => widget.onOpenProfile(outer.account),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: fedi.subtleText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.statusBoostedLabel(
                                outer.account.effectiveDisplayName,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: fedi.subtleText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ),

            // On-device translation offer at the top of an opened post
            if (_canOfferTranslation &&
                _detectedLanguage != null &&
                _osLanguage != null)
              PostTranslationBanner(
                sourceLanguageCode: _detectedLanguage!,
                targetLanguageCode: _osLanguage!,
                isTranslating: _isTranslating,
                showingTranslation: _showingTranslation,
                translationResult: _translationResult,
                errorMessage: _translationError,
                onTranslate: _handleTranslate,
                onToggleOriginal: () {
                  _stopReadAloudIfActive();
                  setState(() => _showingTranslation = !_showingTranslation);
                },
              ),

            // Top-of-post Read Aloud button for an opened post page
            if (widget.enableReadAloud)
              ListenableBuilder(
                listenable: Listenable.merge([
                  widget.app.tts,
                  widget.app.mediaAi,
                  widget.app.quoteCache,
                  widget.app,
                ]),
                builder: (context, _) {
                  final speechText = _buildPostReadAloudText(l10n);
                  if (speechText.isEmpty) return const SizedBox.shrink();
                  final isSpeaking = widget.app.tts.isSpeakingKey(_postTtsKey);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Semantics(
                        button: true,
                        toggled: isSpeaking,
                        label: isSpeaking
                            ? l10n.statusStopReadingPostSemantics
                            : l10n.statusReadAloudPostSemantics,
                        child: AccessibleTip(
                          message: isSpeaking
                              ? l10n.statusStopReadingPostTip
                              : l10n.statusReadAloudPostTip,
                          child: FilledButton.tonalIcon(
                            onPressed: () => widget.app.tts.toggleSpeak(
                              key: _postTtsKey,
                              text: speechText,
                              languageName: _resolveReadAloudLanguage(),
                              speechRate: widget.app.settings.ttsSpeechRate,
                            ),
                            icon: Icon(
                              isSpeaking ? Icons.stop : Icons.volume_up,
                              size: 18,
                            ),
                            label: Text(
                              isSpeaking
                                  ? l10n.mediaStopReadingButton
                                  : l10n.mediaReadAloudButton,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            StatusAuthorHeader(
              status: target,
              onOpenProfile: widget.onOpenProfile,
            ),

            const SizedBox(height: 8),

            if (hasCw) ...[
              ContentWarningBanner(
                spoilerText: _showingTranslation &&
                        (_translationResult?.translatedSpoiler ?? '').isNotEmpty
                    ? _translationResult!.translatedSpoiler!
                    : target.spoilerText,
                revealed: cwRevealed,
                onToggle: widget.onToggleCw ??
                    () => setState(() => _cwRevealed = !_cwRevealed),
              ),
              const SizedBox(height: 8),
            ],

            // Embedded Quoted Post (above reply) + Main post body + Media attachments
            if (!hasCw || cwRevealed) ...[
              ListenableBuilder(
                listenable: widget.app.quoteCache,
                builder: (context, _) {
                  final quoteMatch = _leadingQuote;
                  final quoteUrl = quoteMatch?.quoteUrl;
                  final embeddedQuote = target.quotedStatus ??
                      (quoteUrl != null
                          ? widget.app.cachedQuotedStatus(quoteUrl)
                          : null);
                  final isLoadingQuote = target.quotedStatus == null &&
                      quoteUrl != null &&
                      (widget.app.isResolvingQuote(quoteUrl) ||
                          !widget.app.hasResolvedQuote(quoteUrl));
                  final hasQuoteWindow =
                      target.quotedStatus != null || quoteUrl != null;

                  // Strip redundant leading `RE: <url>` from outer post text when displaying quote window.
                  final bodyHtml = quoteMatch != null
                      ? quoteMatch.remainingHtml
                      : target.contentHtml;
                  final bodyPlainText = HtmlUtils.htmlToPlainText(bodyHtml);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasQuoteWindow)
                        QuotedStatusCard(
                          app: widget.app,
                          quotedStatus: embeddedQuote,
                          quoteUrl: quoteUrl,
                          isLoading: isLoadingQuote,
                          onOpenProfile: widget.onOpenProfile,
                          onOpenThread: widget.onOpenThread,
                          onRetry: quoteUrl != null
                              ? () => widget.app.resolveQuotedStatus(
                                    quoteUrl,
                                    forceRetry: true,
                                  )
                              : null,
                        ),
                      if (hasQuoteWindow && bodyPlainText.isNotEmpty)
                        const SizedBox(height: 6),
                      if (bodyPlainText.isNotEmpty)
                        AccessibleTip(
                          message: l10n.statusOpenThreadTip,
                          child: InkWell(
                            onTap: () => widget.onOpenThread(target),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _showingTranslation &&
                                      (_translationResult?.translatedText ?? '')
                                          .isNotEmpty
                                  ? LinkifiedText.plain(
                                      _translationResult!.translatedText,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    )
                                  : LinkifiedText.html(
                                      bodyHtml,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      mentions: target.mentions,
                                      onTapMention: (mention) =>
                                          widget.onOpenProfile(
                                        mention.toStubAccount(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (target.editedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.statusEditedAt(
                      TimeUtils.formatRelativeCompact(
                        target.editedAt!,
                        l10n: l10n,
                      ),
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: fedi.subtleText),
                  ),
                ),
              for (final media in target.mediaAttachments)
                MediaAttachmentCard(
                  attachment: media,
                  app: widget.app,
                  postContext: target.plainText,
                  translatedAltText: _showingTranslation
                      ? _translationResult?.translatedAltTexts[media.id]
                      : null,
                ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Accessible Action Bar
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionIcon(
                  icon: Icons.reply,
                  label: target.repliesCount > 0 ? '${target.repliesCount}' : '',
                  semanticLabel: l10n.statusReplySemantics(
                    target.account.effectiveDisplayName,
                    target.repliesCount,
                  ),
                  onPressed: () => widget.onReply(target),
                ),
                _ActionIcon(
                  icon: Icons.repeat,
                  label: target.reblogsCount > 0 ? '${target.reblogsCount}' : '',
                  active: target.reblogged,
                  activeColor: scheme.secondary,
                  semanticLabel: target.reblogged
                      ? l10n.statusUnboostSemantics(target.reblogsCount)
                      : l10n.statusBoostSemantics(target.reblogsCount),
                  onPressed: () => widget.onToggleBoost(target),
                ),
                _ActionIcon(
                  icon: target.favourited ? Icons.star : Icons.star_border,
                  label: target.favouritesCount > 0
                      ? '${target.favouritesCount}'
                      : '',
                  active: target.favourited,
                  activeColor: scheme.primary,
                  semanticLabel: target.favourited
                      ? l10n.statusUnfavoriteSemantics(target.favouritesCount)
                      : l10n.statusFavoriteSemantics(target.favouritesCount),
                  onPressed: () => widget.onToggleFavorite(target),
                ),
                _ActionIcon(
                  icon: target.bookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: '',
                  active: target.bookmarked,
                  activeColor: scheme.primary,
                  semanticLabel: target.bookmarked
                      ? l10n.statusRemoveBookmarkSemantics
                      : l10n.statusBookmarkSemantics,
                  onPressed: () => widget.onToggleBookmark(target),
                ),
                _ActionIcon(
                  icon: Icons.forum_outlined,
                  label: l10n.statusThreadActionLabel,
                  semanticLabel: l10n.statusThreadActionSemantics,
                  onPressed: () => widget.onOpenThread(target),
                ),
                if (isOwnPost && widget.onEdit != null)
                  _ActionIcon(
                    icon: Icons.edit,
                    label: l10n.statusEditActionLabel,
                    semanticLabel: l10n.statusEditActionSemantics,
                    onPressed: () => widget.onEdit!(target),
                  ),
                if (isOwnPost && widget.onDelete != null)
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    label: '',
                    activeColor: scheme.error,
                    semanticLabel: l10n.statusDeleteActionSemantics,
                    onPressed: () => widget.onDelete!(target),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = active
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : defaultColor;

    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: AccessibleTip(
        message: semanticLabel,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppConstants.minTouchTargetSize,
              minHeight: AppConstants.minTouchTargetSize,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.normal,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
