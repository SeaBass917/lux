import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Interface to updating user preferences.
/// Preferences are managed through a combination of local storage and
/// cloud storage on a per user basis.
class UserState {
  // Singleton constructor boilerplate
  static final UserState _instance = UserState._internal();
  factory UserState() => _instance;
  UserState._internal() {
    _getSharedPrefs().then((status) {
      _cacheIsValid = status;
    });
  }

  /****************************************************************************
   * Key Definitions                                                          *
   ****************************************************************************/

  /// Key used to store the server address last connected to
  final String _ipLast = "_ipLast";

  /// Key used to store the server port last connected to
  final String _portLast = "_portLast";

  /// Key used to store the jwt token for the current connection
  final String _connectionJWT = "_connectionJWT";

  /// Key used to store the secret pepper for the current connection
  final String _secretPepper = "_secretPepper";

  /// Key used to store the NSFW setting
  final String _nsfwEnabledKey = "_isNSFWEnabled";

  /// Key used to store the Light Theme setting
  final String _lightThemeSettingKey = "_isLightThemeEnabled";

  /// Key used to store the watched/unwatched status of the given [episode]
  /// for [title].
  String _episodeWatchedKey(String title, String episode) =>
      "watched $title/$episode";

  /// Key used to store the last known episode number for a [title].
  String _lastEpisodeKey(String title) => "lastEpisode $title";

  /// Key used to store the last Episode Timestamp for a given
  /// [episode] of a [title].
  String _lastEpisodeTimestampKey(String title, String episode) =>
      "lastEpisodeTS $title/$episode";

  /// Key used to store the last known chapter number for a [title].
  String _lastChapterKey(String title) => "lastChapter $title";

  /// Key used to store the read/unread status of a given [chapter] for [title].
  String _chapterReadKey(String title, String chapter) =>
      "read $title/$chapter";

  /// Key used to store the lastPageNumber for a given [chapter] of a [title].
  String _lastPageKey(String title, String chapter) =>
      "lastPage $title/$chapter";

  /****************************************************************************
   * Network Settings                                                         *
   ****************************************************************************/

  /// Sets the pepper string to [pepper] in the cache.
  /// Returns true if we set successfully, or false is there were any issues.
  Future<bool> setPepper(String pepper) async {
    if (!_cacheIsValid) return false;
    return await _cache.setString(_secretPepper, pepper);
  }

  /// Retrieves the current pepper string from the cache
  /// Returns null if there is no pepper stored in the cache
  String? getPepper() {
    if (!_cacheIsValid) return null;
    return _cache.getString(_secretPepper);
  }

  /// Sets the jwt string to [jwt] in the cache.
  /// Returns true if we set successfully, or false is there were any issues.
  Future<bool> setConnectionJWT(String jwt) async {
    if (!_cacheIsValid) return false;
    return await _cache.setString(_connectionJWT, jwt);
  }

  /// Retrieves the current pepper string from the cache
  /// Returns null if there is no pepper stored in the cache
  String? getConnectionJWT() {
    if (!_cacheIsValid) return null;
    return _cache.getString(_connectionJWT);
  }

  /// Sets the server address to [address] in the cache
  ///
  /// Returns true if we set successfully, or false is there were any issues.
  Future<bool> setServerAddress(String address, String port) async {
    if (!_cacheIsValid) return false;

    bool status = true;
    status &= await _cache.setString(_ipLast, address);
    status &= await _cache.setString(_portLast, port);

    return status;
  }

  /// Retrieves the current server address from the cache
  /// Returns null if there is no address stored in the cache
  String? getServerAddress() {
    if (!_cacheIsValid) return null;
    return _cache.getString(_ipLast);
  }

  /// Retrieves the current server port from the cache
  /// Returns null if there is no port stored in the cache
  String? getServerPort() {
    if (!_cacheIsValid) return null;
    return _cache.getString(_portLast);
  }

  /****************************************************************************
   * System Settings                                                          *
   ****************************************************************************/

  /// Marks light theme as [isEnabled] in the cache
  ///
  /// Returns true if we set successfully, or false is there were any issues.
  Future<bool> setLightThemeStatus(bool isEnabled) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // If we are marking as read, add it, else just remove the entry
    // No need to store a bunch of "not read" titles in the cache
    return await _cache.setBool(_lightThemeSettingKey, isEnabled);
  }

  /// Checks the cache to see if light theme has been enabled
  /// is read(true) or unread(false).
  bool getLightThemeStatus() {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    return _cache.getBool(_lightThemeSettingKey) ?? false;
  }

  /// Marks NSFW content as [isEnabled] in the cache
  ///
  /// Returns true if we set successfully, or false is there were any issues.
  Future<bool> setNSFWEnabledStatus(bool isEnabled) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // If we are marking as read, add it, else just remove the entry
    // No need to store a bunch of "not read" titles in the cache
    return await _cache.setBool(_nsfwEnabledKey, isEnabled);
  }

  /// Checks the cache to see if NSFW content has been enabled
  /// is read(true) or unread(false).
  bool getNSFWEnabledStatus() {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    return _cache.getBool(_nsfwEnabledKey) ?? false;
  }

  /****************************************************************************
   * Video Settings                                                           *
   ****************************************************************************/

  /// Marks a given [episode] of a [title] as read or unread in the cache.
  /// [isWatched] == True, mark as read, else mark as unread.
  Future<bool> setEpisodeWatchedStatus(
      String title, String episode, bool isWatched) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // If we are marking as read, add it, else just remove the entry
    // No need to store a bunch of "not read" titles in the cache
    if (isWatched) {
      return await _cache.setBool(_episodeWatchedKey(title, episode), true);
    } else {
      return await _cache.remove(_episodeWatchedKey(title, episode));
    }
  }

  /// Checks the cache to see if a given [episode] of a [title]
  /// is read(true) or unread(false).
  bool getEpisodeWatchedStatus(String title, String episode) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    return _cache.getBool(_episodeWatchedKey(title, episode)) ?? false;
  }

  /// Store the last known [episode] for the given [title].
  ///
  /// Returns Status of the store operation.
  Future<bool> setLastEpisode(String title, String episode) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // Attempt to set the last chapter string
    try {
      return await _cache.setString(_lastEpisodeKey(title), episode);
    } catch (err) {
      print(err);
    }
    return false;
  }

  /// Retrieve the last known chapter for the given [title].
  ///
  /// Returns Last chapter as a string, or null if there is no last chapter
  ///         Also returns null if there is an internal error preventing
  ///         access to the data.
  String? getLastEpisode(String title) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return null;

    // Attempt to set the last chapter string
    return _cache.getString(_lastEpisodeKey(title));
  }

  /// Store the last known [timestampSeconds] for a given [episode]
  /// of a [title].
  ///
  /// Returns Status of the store operation.
  Future<bool> setLastTimestampForEpisode(
      String title, String episode, int timestampSeconds) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // Store the
    try {
      return await _cache.setInt(
          _lastEpisodeTimestampKey(title, episode), timestampSeconds);
    } catch (err) {
      print(err);
    }
    return false;
  }

  /// Retrieve the last known timestamp in seconds
  /// for a given [episode] of a [title].
  ///
  /// Returns Last known timestamp as an int, or 0 if none was found.
  ///         Also returns 0 if there is an internal error preventing
  ///         access to the data.
  int getLastTimestampForEpisode(String title, String episode) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return 0;

    // Lookup the chapter key, if none found then default to 0 seconds
    return _cache.getInt(_lastEpisodeTimestampKey(title, episode)) ?? 0;
  }

  /****************************************************************************
   * Manga Settings                                                           *
   ****************************************************************************/

  /// Marks a given [chapter] of a [title] as read or unread in the cache.
  /// [isRead] == True, mark as read, else mark as unread.
  Future<bool> setChapterReadStatus(
      String title, String chapter, bool isRead) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // If we are marking as read, add it, else just remove the entry
    // No need to store a bunch of "not read" titles in the cache
    if (isRead) {
      return await _cache.setBool(_chapterReadKey(title, chapter), true);
    } else {
      return await _cache.remove(_chapterReadKey(title, chapter));
    }
  }

  /// Checks the cache to see if a given [chapter] of a [title]
  /// is read(true) or unread(false).
  bool getChapterReadStatus(String title, String chapter) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    return _cache.getBool(_chapterReadKey(title, chapter)) ?? false;
  }

  /// Store the last known [chapter] for the given [title].
  ///
  /// Returns Status of the store operation.
  Future<bool> setLastChapter(String title, String chapter) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // Attempt to set the last chapter string
    try {
      return await _cache.setString(_lastChapterKey(title), chapter);
    } catch (err) {
      print(err);
    }
    return false;
  }

  /// Retrieve the last known chapter for the given [title].
  ///
  /// Returns Last chapter as a string, or null if there is no last chapter
  ///         Also returns null if there is an internal error preventing
  ///         access to the data.
  String? getLastChapter(String title) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return null;

    // Attempt to set the last chapter string
    return _cache.getString(_lastChapterKey(title));
  }

  /// Store the last known [page] for a given [chapter] of a [title].
  ///
  /// Returns Status of the store operation.
  Future<bool> setLastPageForChapter(
      String title, String chapter, int page) async {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return false;

    // Store the
    try {
      return await _cache.setInt(_lastPageKey(title, chapter), page);
    } catch (err) {
      print(err);
    }
    return false;
  }

  /// Retrieve the last known page for a given [chapter] of a [title].
  /// Returns the last known page for this chapter.
  ///
  /// Returns Last known page as an int, or 1 if none was found.
  ///         Also returns 1 if there is an internal error preventing
  ///         access to the data.
  int getLastPageForChapter(String title, String chapter) {
    // Make sure shared preferences are loaded
    if (!_cacheIsValid) return 1;

    // Lookup the chapter key, if none found then default to page 1
    return _cache.getInt(_lastPageKey(title, chapter)) ?? 1;
  }

  /// Returns the [bool] flag indicating if the cache is valid.
  bool isCacheValid() {
    return _cacheIsValid;
  }

  /****************************************************************************
   * Private                                                                  *
   ****************************************************************************/

  /// Preferences data manager. Caches user data locally.
  /// To be loaded late in constructor
  late SharedPreferences _cache;

  /// Status flag indicating that the preferences data we have is safe to use.
  bool _cacheIsValid = false;

  /// Set up the instance of the shared preferences accessor.
  ///
  /// Returns true if successful, false if anything goes wrong.
  ///         Logs the failure in the case of a failure.
  Future<bool> _getSharedPrefs() async {
    try {
      _cache = await SharedPreferences.getInstance();
      return true;
    } catch (err) {
      print(err);
    }
    return false;
  }
}
