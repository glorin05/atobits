# Keep Flutter engine and plugin classes.
# (Flutter Gradle plugin also supplies its own keep rules; these are a safe baseline.)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Keep the Android entrypoint.
-keep class com.example.havbits.MainActivity { *; }
