// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

#import "GoogleMlKitCommonsPlugin.h"

@implementation GoogleMlKitCommonsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  // No-op on iOS; TranslationService uses Apple Foundation Models / Apple Translation.
}
@end
