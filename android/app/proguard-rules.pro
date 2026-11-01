# Flutter / plugins ship their own consumer rules. Keep the components Android instantiates
# by name from the manifest and from persisted alarm intents.
-keep class com.personal.phone_addiction_controller.MainActivity { *; }
-keep class com.personal.phone_addiction_controller.services.** { *; }
-keep class com.personal.phone_addiction_controller.receivers.** { *; }