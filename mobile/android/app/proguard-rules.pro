# google_mlkit_text_recognition declares the Chinese, Devanagari, Japanese and
# Korean recognizers as `compileOnly`, so their classes are referenced by the
# plugin but never packaged. Only Latin is used here, which is all the
# Play-Services model provides, so R8 is told not to warn about the rest.
#
# Without this the release build fails outright at :minifyStandardReleaseWithR8.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# The ML Kit entry points are resolved reflectively by Play Services, so the
# optional-module registrar must survive shrinking.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text** { *; }
