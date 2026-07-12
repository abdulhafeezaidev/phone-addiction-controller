import 'package:flutter/services.dart';
import '../interfaces/system_package_service.dart';

class SystemPackageServiceImpl implements SystemPackageService {
  static const MethodChannel _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  Future<bool> isSystemPackage(String packageName) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'isSystemPackage',
        {'packageName': packageName},
      );
      return result ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }
}
