# flutter_local_notifications persists scheduled notifications as JSON in
# SharedPreferences and reads them back with Gson, through a generic
# TypeToken. R8 erases generic signatures by default, so on a release build
# that read fails with:
#
#   java.lang.RuntimeException: Missing type parameter.
#       at FlutterLocalNotificationsPlugin.loadScheduledNotifications
#       at FlutterLocalNotificationsPlugin.rescheduleNotifications
#       at ScheduledNotificationBootReceiver
#
# which crashes the process whenever that receiver runs — on boot, and on
# MY_PACKAGE_REPLACED, i.e. every single app update.
#
# -keepattributes Signature is the fix: it preserves the generic type
# information Gson needs. The others keep the plugin's own model classes,
# which are only referenced reflectively.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Gson itself: TypeToken subclasses must keep their signatures, and fields of
# serialised models must not be renamed.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# google_mlkit_text_recognition references the CJK/Devanagari readers, which
# are deliberately not bundled (Latin is enough for cards and UPI receipts).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit creates its component registrars by reflection; without this R8
# strips their constructors and the text reader never starts (shared
# receipts and card scans silently read nothing in release builds).
-keep class com.google.mlkit.** { *; }
