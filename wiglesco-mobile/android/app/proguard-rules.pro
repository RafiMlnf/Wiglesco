# ── Wiglesco Mobile ProGuard Rules ──────────────────────────────────

# ── Flutter Engine & Embedding ────────────────────────────────────────
# The GeneratedPluginRegistrant registers all plugins at startup.
# Without this, ALL plugins will fail with channel-error.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Keep ALL classes that implement FlutterPlugin (plugin entry points).
# R8 tree-shakes these because no Java code calls them directly.
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keepclassmembers class * implements io.flutter.embedding.engine.plugins.FlutterPlugin {
    public void onAttachedToEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
    public void onDetachedFromEngine(io.flutter.embedding.engine.plugins.FlutterPlugin$FlutterPluginBinding);
}

# Keep Activity-aware plugins
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }

# ── AndroidX Lifecycle ────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# ── Pigeon (type-safe plugin message codegen) ──────────────────────────
# Pigeon generates Flutter↔Java bridge code. R8 strips it in release.
-keep class dev.flutter.pigeon.** { *; }
-dontwarn dev.flutter.pigeon.**

# ── ONNX Runtime ──────────────────────────────────────────────────────
-keep class com.microsoft.onnxruntime.** { *; }
-keep class ai.onnxruntime.** { *; }
-dontwarn com.microsoft.onnxruntime.**
-dontwarn ai.onnxruntime.**

# ── Dart FFI JNI (package:jni) ────────────────────────────────────────
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn com.github.dart_lang.jni.**

# ── FFmpeg Kit ────────────────────────────────────────────────────────
-keep class com.arthenica.** { *; }
-dontwarn com.arthenica.**

# ── OkHttp / Dio ─────────────────────────────────────────────────────
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Google Play Services ──────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Permission Handler ────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── Share Plus ────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# ── Gal (Save to gallery) ─────────────────────────────────────────────
-keep class app.galeria.** { *; }
-dontwarn app.galeria.**

# ── General: Annotations, Signatures, Native Methods ─────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepclassmembers class * {
    native <methods>;
}
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Suppress known benign warnings ────────────────────────────────────
-dontwarn javax.annotation.**
-dontwarn kotlin.reflect.jvm.internal.**
-dontwarn com.google.android.play.core.**
