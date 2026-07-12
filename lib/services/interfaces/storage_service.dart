/// Abstract interface for the local Storage Service.
///
/// Wraps Hive for type-safe, key-value persistence.
abstract class StorageService {
  /// Stores a [value] under the given [key].
  Future<void> put<T>(String boxName, String key, T value);

  /// Retrieves the value for [key], or [defaultValue] if not found.
  T? get<T>(String boxName, String key, {T? defaultValue});

  /// Deletes the entry for [key].
  Future<void> delete(String boxName, String key);

  /// Returns all values stored in [boxName].
  List<T> getAll<T>(String boxName);

  /// Clears all entries in [boxName].
  Future<void> clearBox(String boxName);

  /// Returns true if [key] exists in [boxName].
  bool containsKey(String boxName, String key);
}
