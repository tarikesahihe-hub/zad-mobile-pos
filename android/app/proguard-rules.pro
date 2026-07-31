# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# local_auth
-keep class androidx.biometric.** { *; }

# Play Core (referenced by Flutter's deferred components engine, unused in this app)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
