abstract class SystemPackageService {
  /// Classifies whether a package is a system or updated system package internally.
  Future<bool> isSystemPackage(String packageName);
}
