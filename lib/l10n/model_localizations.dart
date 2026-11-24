// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/composer_attachment.dart';
import '../models/mastodon_models.dart';
import '../services/on_device_ai_service.dart';
import 'generated/app_localizations.dart';

/// UI-localized display strings for [PolicyMode].
extension PolicyModeL10n on PolicyMode {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      PolicyMode.warn => l10n.policyModeWarnLabel,
      PolicyMode.require => l10n.policyModeRequireLabel,
      PolicyMode.off => l10n.policyModeOffLabel,
    };
  }

  String localizedAltPolicySubtitle(AppLocalizations l10n) {
    return switch (this) {
      PolicyMode.warn => l10n.altPolicyWarnSubtitle,
      PolicyMode.require => l10n.altPolicyRequireSubtitle,
      PolicyMode.off => l10n.altPolicyOffSubtitle,
    };
  }

  String localizedBiasPolicySubtitle(AppLocalizations l10n) {
    return switch (this) {
      PolicyMode.warn => l10n.biasPolicyWarnSubtitle,
      PolicyMode.require => l10n.biasPolicyRequireSubtitle,
      PolicyMode.off => l10n.biasPolicyOffSubtitle,
    };
  }
}

/// UI-localized display strings for [ThemePreference].
extension ThemePreferenceL10n on ThemePreference {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      ThemePreference.system => l10n.themeSystemLabel,
      ThemePreference.dark => l10n.themeDarkLabel,
      ThemePreference.light => l10n.themeLightLabel,
      ThemePreference.highContrast => l10n.themeHighContrastLabel,
    };
  }
}

/// UI-localized display strings for [AiProviderType].
extension AiProviderTypeL10n on AiProviderType {
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (this) {
      AiProviderType.onDevice => l10n.aiProviderOnDeviceLabel,
      AiProviderType.gemini => l10n.aiProviderGeminiLabel,
      AiProviderType.openai => l10n.aiProviderOpenAiLabel,
      AiProviderType.anthropic => l10n.aiProviderAnthropicLabel,
      AiProviderType.local => l10n.aiProviderLocalLabel,
      AiProviderType.none => l10n.aiProviderNoneLabel,
    };
  }
}

/// UI-localized display strings for [CaptionDetailLevel].
extension CaptionDetailLevelL10n on CaptionDetailLevel {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      CaptionDetailLevel.concise => l10n.detailLevelConciseLabel,
      CaptionDetailLevel.descriptive => l10n.detailLevelDescriptiveLabel,
      CaptionDetailLevel.detailed => l10n.detailLevelDetailedLabel,
    };
  }

  String localizedGuidance(AppLocalizations l10n) {
    return switch (this) {
      CaptionDetailLevel.concise => l10n.detailLevelConciseGuidance,
      CaptionDetailLevel.descriptive => l10n.detailLevelDescriptiveGuidance,
      CaptionDetailLevel.detailed => l10n.detailLevelDetailedGuidance,
    };
  }
}

/// UI-localized display strings for [TimelineType].
extension TimelineTypeL10n on TimelineType {
  String localizedShortLabel(AppLocalizations l10n) {
    return switch (this) {
      TimelineType.home => l10n.timelineHomeShort,
      TimelineType.local => l10n.timelineLocalShort,
      TimelineType.federated => l10n.timelineFederatedShort,
      TimelineType.notifications => l10n.timelineAlertsShort,
      TimelineType.bookmarks => l10n.timelineBookmarksShort,
      TimelineType.favorites => l10n.timelineFavoritesShort,
      TimelineType.myPosts => l10n.timelineMyPostsShort,
    };
  }

  String localizedFullTitle(AppLocalizations l10n) {
    return switch (this) {
      TimelineType.home => l10n.timelineHomeFull,
      TimelineType.local => l10n.timelineLocalFull,
      TimelineType.federated => l10n.timelineFederatedFull,
      TimelineType.notifications => l10n.timelineNotificationsFull,
      TimelineType.bookmarks => l10n.timelineBookmarksShort,
      TimelineType.favorites => l10n.timelineFavoritesShort,
      TimelineType.myPosts => l10n.timelineMyPostsFull,
    };
  }
}

/// UI-localized display strings for [PostVisibility].
extension PostVisibilityL10n on PostVisibility {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      PostVisibility.public => l10n.postVisibilityPublicLabel,
      PostVisibility.unlisted => l10n.postVisibilityUnlistedLabel,
      PostVisibility.private => l10n.postVisibilityPrivateLabel,
      PostVisibility.direct => l10n.postVisibilityDirectLabel,
    };
  }

  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      PostVisibility.public => l10n.postVisibilityPublicDesc,
      PostVisibility.unlisted => l10n.postVisibilityUnlistedDesc,
      PostVisibility.private => l10n.postVisibilityPrivateDesc,
      PostVisibility.direct => l10n.postVisibilityDirectDesc,
    };
  }
}

/// UI-localized display strings for [AttachmentStatus].
extension AttachmentStatusL10n on AttachmentStatus {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      AttachmentStatus.scanning => l10n.attachmentStatusScanning,
      AttachmentStatus.ready => l10n.attachmentStatusReady,
      AttachmentStatus.missingAltText => l10n.attachmentStatusMissingAltText,
      AttachmentStatus.error => l10n.attachmentStatusError,
    };
  }
}

/// UI-localized display strings for [MastodonNotification].
extension MastodonNotificationL10n on MastodonNotification {
  String localizedSummary(AppLocalizations l10n) {
    final author = account.effectiveDisplayName;
    return switch (type) {
      'mention' => l10n.notificationMentionSummary(author),
      'reblog' => l10n.notificationReblogSummary(author),
      'favourite' => l10n.notificationFavouriteSummary(author),
      'follow' => l10n.notificationFollowSummary(author),
      'follow_request' => l10n.notificationFollowRequestSummary(author),
      'status' => l10n.notificationStatusSummary(author),
      'update' => l10n.notificationUpdateSummary(author),
      'poll' => l10n.notificationPollSummary(author),
      'quote' => l10n.notificationQuoteSummary(author),
      'quoted_update' => l10n.notificationQuotedUpdateSummary(author),
      _ => l10n.notificationGenericSummary(author, type),
    };
  }
}

/// UI-localized display strings for [OnDeviceAiStatus].
extension OnDeviceAiStatusL10n on OnDeviceAiStatus {
  String localizedEngineName(AppLocalizations l10n) {
    return switch (engineName) {
      'Web (no OS on-device model)' => l10n.onDeviceAiEngineWeb,
      'Apple Foundation Models' => l10n.onDeviceAiEngineApple,
      'Google Gemini Nano (ML Kit GenAI / AICore)' =>
        l10n.onDeviceAiEngineGeminiNano,
      'On-Device AI' => l10n.onDeviceAiEngineGeneric,
      _ => engineName,
    };
  }

  String localizedDiagnosticDetail(AppLocalizations l10n) {
    final promptExtra = promptDiagnostic != null ? ' ($promptDiagnostic)' : '';
    final imageExtra =
        imageDescriptionDiagnostic != null ? ' ($imageDescriptionDiagnostic)' : '';
    return l10n.onDeviceAiDiagnosticDetail(
      promptAvailability.name,
      promptExtra,
      imageDescriptionAvailability.name,
      imageExtra,
    );
  }

  String localizedSummaryMessage(AppLocalizations l10n) {
    final name = localizedEngineName(l10n);
    if (isReady) {
      if (isImageDescriberReady && isPromptReady) {
        return l10n.onDeviceAiSummaryReadyBoth(name);
      }
      if (isImageDescriberReady) {
        return l10n.onDeviceAiSummaryReadyDescriberOnly(name);
      }
      return l10n.onDeviceAiSummaryReadyPromptOnly(name);
    }
    if (isDownloadable) {
      return l10n.onDeviceAiSummaryDownloadable(name);
    }
    if (isNotYetReady) {
      return l10n.onDeviceAiSummaryNotYetReady(name);
    }
    return l10n.onDeviceAiSummaryUnavailable(name);
  }
}

/// UI-localized display strings for built-in on-device [AiModelOption] choices.
extension AiModelOptionL10n on AiModelOption {
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (id) {
      OnDeviceAiService.modelAuto => l10n.aiModelOnDeviceAuto,
      OnDeviceAiService.modelImageDescriber => l10n.aiModelOnDeviceDescriber,
      OnDeviceAiService.modelMultimodalPrompt => l10n.aiModelOnDevicePrompt,
      _ => displayName,
    };
  }
}
