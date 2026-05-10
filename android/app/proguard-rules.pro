# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# General Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ✅ Fix: Missing Play Core classes (R8 error)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Meta Audience Network
-keep class com.facebook.** { *; }
-keepattributes *Annotation*
-dontwarn com.facebook.infer.annotation.**
-dontwarn com.facebook.ads.**