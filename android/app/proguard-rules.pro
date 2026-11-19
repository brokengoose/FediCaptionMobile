# Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
# SPDX-License-Identifier: MIT

# Preserve ML Kit GenAI, AICore AIDL/binder classes, and edge_gen_ai plugin bridge in release builds
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.apps.aicore.** { *; }
-keep interface com.google.android.apps.aicore.** { *; }
-keep class com.manukj.edge_gen_ai.** { *; }
-keep interface com.manukj.edge_gen_ai.** { *; }
-keep class * implements com.google.mlkit.genai.schema.guided.GenerableProvider { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.apps.aicore.**
