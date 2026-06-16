# Flutter 混淆规则 - 保留所有 Flutter 相关类
-keep class io.flutter.** { *; }
-keep class com.counter.flutter_app.** { *; }
-keep class com.teamfox.flutter_overlay_window.** { *; }

# R8 全量模式：忽略 Flutter 引擎引用的 Play Core 类（此项目不使用 deferred components）
-dontwarn com.google.android.play.core.**