import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'allowed_app.g.dart';

/// Represents an application that is permitted during Focus Mode.
@HiveType(typeId: AppConstants.allowedAppTypeId)
class AllowedApp extends HiveObject with EquatableMixin {
  /// Android package name (e.g. com.whatsapp).
  @HiveField(0)
  String packageName;

  /// Human-readable application name.
  @HiveField(1)
  String appName;

  /// Raw bytes of the app icon (PNG). May be null if unavailable.
  @HiveField(2)
  Uint8List? icon;

  /// Whether this app is currently whitelisted.
  @HiveField(3)
  bool isAllowed;

  AllowedApp({
    required this.packageName,
    required this.appName,
    this.icon,
    this.isAllowed = true,
  });

  AllowedApp copyWith({
    String? packageName,
    String? appName,
    Uint8List? icon,
    bool? isAllowed,
  }) {
    return AllowedApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      icon: icon ?? this.icon,
      isAllowed: isAllowed ?? this.isAllowed,
    );
  }

  @override
  List<Object?> get props => [packageName, appName, isAllowed];
}
