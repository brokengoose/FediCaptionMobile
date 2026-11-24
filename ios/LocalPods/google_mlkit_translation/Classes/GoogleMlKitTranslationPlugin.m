// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

#import "GoogleMlKitTranslationPlugin.h"

@implementation GoogleMlKitTranslationPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  // No-op on iOS; TranslationService uses Apple Foundation Models / Apple Translation.
}
@end
