import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:lux/manga_lib/manga_metadata.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:lux/videos_lib/video_metadata.dart';
import 'package:video_player/video_player.dart';
import 'package:bcrypt/bcrypt.dart';

/**************************
 * Constants
 **************************/

// TODO: Move this under configuration?
/// Server Port
const String serverPort = "8081";

// Endpoints
const String endpointGetPepper = "auth/pepper";
const String endpointGetAuthToken = "auth/auth-token";

const String endpointMangaCollectionIndex = "manga/collection-index";
const String endpointMangaMetaDataByTitle = "manga/metadata";
const String endpointMangaChaptersByTitle = "manga/chapters";

const String endpointVideoCollectionIndex = "video/collection-index";
const String endpointVideoMetaDataByTitle = "video/metadata";
const String endpointVideoEpisodesByTitle = "video/episodes";
const String endpointSubtitleSelections = "video/subtitle-selections";
const String endpointSubtitlesChewieFmt = "video/subtitles-chewie";

// Known Paths
const String pathManga = "manga";
const String pathVideo = "video";
const String pathMusic = "music";
const String pathImage = "images";
const String pathSubtitles = "subtitles";
const String pathMangaThumbnail = "lux-assets/thumbnails/manga/";
const String pathMangaCoverArt = "lux-assets/covers/manga/";
const String pathVideoThumbnail = "lux-assets/thumbnails/video/";
const String pathVideoCoverArt = "lux-assets/covers/video/";
const String pathMusicThumbnail = "lux-assets/thumbnails/music/";
const String pathMusicCoverArt = "lux-assets/covers/music/";

// TODO: This is jank af. Have this be a local resource
//       The reason it is currently not, is because the list is a list of
//       Network images. So, you'd need to find some common class, etc...
const String endpointBlackPng = "public/assets/images/_black.png";

/**************************
 * General Helper Functions
 **************************/

/// Helper for building the default icon image asset
///   - `mediaType`  "manga"/"video"/"music"
///   - `fit`        ...
///   - `width`      ...
///   - `height`     ...
Image getDefaultIconAsset(String mediaType,
    {BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Alignment alignment = Alignment.center}) {
  return Image.asset(
    'assets/icons/default-$mediaType-icon.png',
    fit: fit,
    alignment: alignment,
    height: height,
    width: width,
  );
}

/// Returns a [CachedNetworkImage] from the specified
/// [address], [port], and [path].
/// Specify the [mediaType] as "manga"/"video"/"music".
/// Optionally Specify the [width], [height], or [fit] of the image.
CachedNetworkImage getCachedNetworkImage(
    String address, String port, String path, String mediaType,
    {double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center}) {
  final String url = "http://$address:$port/$path";
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    height: height,
    width: width,
    alignment: alignment,
    placeholder: (context, url) => getDefaultIconAsset(
      mediaType,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
    ),
    errorWidget: (context, url, error) => getDefaultIconAsset(
      mediaType,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
    ),
  );
}

/// Returns a [NetworkImage] of the black png on the server.
NetworkImage getBlackPng() {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  return NetworkImage("http://$address:$port/$endpointBlackPng");
}

/// Returns a [String] of the provided [strings] joined by commas,
/// with all '+' replaced with '%2B'.
String stringifyRequestStringList(List<String> strings) {
  for (int i = 0; i < strings.length; i++) {
    strings[i] = Uri.encodeComponent(strings[i]);
  }
  return strings.join(",");
}

/**************************
 * Server Auth Functions
 **************************/

/// Convert the provided [jwt] to a signed folder name
/// Returns a [String] of the signed folder name
String convertJWTToSignedFolder(String jwt) {
  if (jwt.length < 25) {
    return jwt;
  }
  return jwt.substring(jwt.length - 25);
}

/// Get the pepper from the specified server [address]
/// Returns a [String] of the pepper
Future<String> getPepperFromServer(String address, String port) async {
  final http.Response res = await http
      .get(Uri.parse("http://$address:$port/$endpointGetPepper"))
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception("Server timed out."),
      );

  if (res.statusCode != 200) {
    throw Exception(res.body);
  }
  return res.body;
}

/// Get an auth jwt from the specified server [ip],
/// given the provided [pwd] and [pepper].
/// Returns a [String] of the jwt, or and empty string if the server
/// rejects the password.
/// Raises an [Exception] if the server is unreachable.
Future<String> getJWTFromServer(
    String address, String port, String pwd, String pepper) async {
  // Hash together the password and pepper
  final String pwdHash = BCrypt.hashpw(pwd, pepper);

  http.Response res = await http.post(
    Uri.parse("http://$address:$port/$endpointGetAuthToken"),
    body: {
      "pwdHash": pwdHash,
    },
  ).timeout(
    const Duration(seconds: 5),
    onTimeout: () => throw Exception("Server timed out."),
  );

  if (res.statusCode == 401) {
    return "";
  } else if (res.statusCode != 200) {
    throw Exception(res.body);
  }

  return res.body;
}

/**************************
 * Manga Functions
 **************************/

/// Get the index of the manga collection from the specified server [address]
/// Returns a [List] of [MangaMetaData].
/// Raises an [Exception] if the server is unreachable.
Future<List<MangaMetaData>> getMangaIndex() async {
  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse("http://$address:$port/$endpointMangaCollectionIndex"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("${res.statusCode} - ${res.body}");
  }

  // Convert the metadata list to a list of manga metadata objects
  dynamic metadataList = json.decode(res.body);
  List<MangaMetaData> mangaMetaDataList = [];
  for (int i = 0; i < metadataList.length; i++) {
    try {
      MangaMetaData data = MangaMetaData.fromJson(metadataList[i]);
      if (data.checkRequiredFieldsThumbnail()) {
        mangaMetaDataList.add(data);
      } else {
        final String title = data.title ?? "<error>";
        print("Manga $title is missing required metadata.");
      }
    } catch (err) {
      final String title = metadataList[i]["title"] ?? "<error>";
      print("Error parsing manga $title metadata: $err");
    }
  }

  return mangaMetaDataList;
}

/// Returns a [CachedNetworkImage] image of the thumbnail art for the specified
/// manga [title] with [width] and [height].
CachedNetworkImage getMangaThumbnailArt(
    String title, double width, double height,
    {BoxFit fit = BoxFit.cover}) {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return getCachedNetworkImage(
    address,
    port,
    "public/${convertJWTToSignedFolder(jwt)}/$pathMangaThumbnail$title.jpg",
    "manga",
    width: width,
    height: height,
  );
}

/// Returns a [CachedNetworkImage] image of the cover art for the specified
/// manga [title] with [width] and [height].
CachedNetworkImage getMangaCoverArt(String title, double width, double height) {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return getCachedNetworkImage(
    address,
    port,
    "public/${convertJWTToSignedFolder(jwt)}/$pathMangaCoverArt$title.jpg",
    "manga",
    width: width,
    height: height,
    alignment: Alignment.topCenter,
  );
}

/// Returns a [List] of [MangaMetaData] for the specified [titles].
Future<List<MangaMetaData>> getMangaMetaDataByTitles(
    List<String> titles) async {
  /// Stringify the title list
  final String titlesString = stringifyRequestStringList(titles);

  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointMangaMetaDataByTitle?titles=$titlesString"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode == 401) {
    throw Exception("Unauthorized!");
  } else if (res.statusCode != 207) {
    throw Exception(
        "Error ${res.statusCode} Failed to load manga metadata for $titles");
  }

  dynamic metadataList = json.decode(res.body);
  List<MangaMetaData> mangaMetaDataList = [];
  for (int i = 0; i < metadataList.length; i++) {
    try {
      // Error handling from the server
      final dynamic dataStatusMap = metadataList[i];
      if (!dataStatusMap.containsKey("status") ||
          !dataStatusMap.containsKey("data")) {
        throw Exception("Invalid metadata format from server.");
      }
      if (dataStatusMap["status"] != 200) {
        throw Exception(
            "Error, $i returned status code ${dataStatusMap["status"]}");
      }

      // Parse the data into a metadata file
      Map<String, dynamic> data = dataStatusMap["data"];
      MangaMetaData metadata = MangaMetaData.fromJson(data);
      if (metadata.checkRequiredFieldsInfoPage()) {
        mangaMetaDataList.add(metadata);
      } else {
        final String title = metadata.title ?? "<error>";
        print("Manga $title is missing required metadata.");
      }
    } catch (err) {
      print("Error parsing manga metadata: $err");
    }
  }

  return mangaMetaDataList;
}

/// Returns a [List] of [MangaChapterIndex] for the specified [titles].
Future<List<Map<String, List<String>>>> getMangaChaptersByTitle(
    List<String> titles) async {
  /// Stringify the title list
  final String titlesString = stringifyRequestStringList(titles);

  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointMangaChaptersByTitle?titles=$titlesString"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode == 401) {
    throw Exception("Unauthorized!");
  } else if (res.statusCode != 207) {
    throw Exception(
        "Error ${res.statusCode} Failed to load manga chapters for $titles");
  }

  try {
    List<Map<String, List<String>>> chaptersLists = [];

    List<dynamic> decodedData = json.decode(res.body);
    for (Map<String, dynamic> data in decodedData) {
      if (!data.containsKey("status") || !data.containsKey("data")) {
        throw Exception("Invalid metadata format from server.");
      }
      if (data["status"] != 200) {
        throw Exception("Error, returned status code ${data["status"]}");
      }

      // Loop through the map of chapters and their contents, and parse them
      //into a typed variable
      Map<String, List<String>> chapterIndex = {};
      Map<String, dynamic> chapters = data["data"];
      for (String chapter in chapters.keys) {
        chapterIndex[chapter] = List<String>.from(chapters[chapter]);
      }

      chaptersLists.add(chapterIndex);
    }
    return chaptersLists;
  } catch (err) {
    print("Error parsing manga chapters: $err");
    return [];
  }
}

/// Returns a [NetworkImage] image of the specified manga [page]
NetworkImage getMangaPage(String title, String chapter, String page) {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return NetworkImage(
      "http://$address:$port/public/${convertJWTToSignedFolder(jwt)}/$pathManga/$title/$chapter/$page");
}

/**************************
 * Video Functions
 **************************/

/// Get the index of the video collection from the specified server
Future<List<VideoMetaData>> getVideoIndex() async {
  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse("http://$address:$port/$endpointVideoCollectionIndex"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode != 200) {
    throw Exception("${res.statusCode} - ${res.body}");
  }

  // Convert the metadata list to a list of Video metadata objects
  dynamic metadataList = json.decode(res.body);
  List<VideoMetaData> videoMetaDataList = [];
  for (int i = 0; i < metadataList.length; i++) {
    try {
      VideoMetaData data = VideoMetaData.fromJson(metadataList[i]);
      if (data.checkRequiredFieldsThumbnail()) {
        videoMetaDataList.add(data);
      } else {
        final String title = data.title ?? "<error>";
        print("Video $title is missing required metadata.");
      }
    } catch (err) {
      final String title = metadataList[i]["title"] ?? "<error>";
      print("Error parsing video $title metadata: $err");
    }
  }

  return videoMetaDataList;
}

/// Returns a [CachedNetworkImage] image of the thumbnail art for the specified
/// video [title] with [width] and [height].
CachedNetworkImage getVideoThumbnailArt(
    String title, double width, double height,
    {BoxFit fit = BoxFit.cover}) {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return getCachedNetworkImage(
    address,
    port,
    "public/${convertJWTToSignedFolder(jwt)}/$pathVideoThumbnail$title.jpg",
    "manga",
    width: width,
    height: height,
  );
}

/// Returns a [CachedNetworkImage] image of the cover art for the specified
/// video [title] with [width] and [height].
CachedNetworkImage getVideoCoverArt(String title,
    {double? width, double? height, BoxFit fit = BoxFit.cover}) {
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return getCachedNetworkImage(
    address,
    port,
    "public/${convertJWTToSignedFolder(jwt)}/$pathVideoCoverArt$title.jpg",
    "video",
    width: width,
    height: height,
  );
}

/// Returns a [CachedNetworkImage] image of the cover art for the specified
/// video [title] with [width] and [height].
Future<List<VideoMetaData>> getVideoMetaDataByTitle(List<String> titles) async {
  /// Stringify the title list
  final String titlesString = stringifyRequestStringList(titles);

  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointVideoMetaDataByTitle?titles=$titlesString"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode == 401) {
    throw Exception("Unauthorized!");
  } else if (res.statusCode != 207) {
    throw Exception(
        "Error ${res.statusCode} Failed to load video metadata for $titles");
  }

  dynamic metadataList = json.decode(res.body);

  List<VideoMetaData> videoMetaDataList = [];
  for (int i = 0; i < metadataList.length; i++) {
    try {
      // Error handling from the server
      final dynamic dataStatusMap = metadataList[i];
      if (!dataStatusMap.containsKey("status") ||
          !dataStatusMap.containsKey("data")) {
        throw Exception("Invalid metadata format from server.");
      }
      if (dataStatusMap["status"] != 200) {
        throw Exception(
            "Error, $i returned status code ${dataStatusMap["status"]}");
      }

      // Parse the data into a metadata file
      Map<String, dynamic> data = dataStatusMap["data"];
      VideoMetaData metadata = VideoMetaData.fromJson(data);
      if (metadata.checkRequiredFieldsInfoPage()) {
        videoMetaDataList.add(metadata);
      } else {
        final String title = metadata.title ?? "<error>";
        print("Video $title is missing required metadata.");
      }
    } catch (err) {
      print("Error parsing video metadata: $err");
    }
  }

  return videoMetaDataList;
}

/// Returns a [List] of [episodes] for the specified [titles].
Future<List<List<String>>> getVideoEpisodesByTitle(List<String> titles) async {
  /// Stringify the title list
  final String titlesString = stringifyRequestStringList(titles);

  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointVideoEpisodesByTitle?titles=$titlesString"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  if (res.statusCode == 401) {
    throw Exception("Unauthorized!");
  } else if (res.statusCode != 207) {
    throw Exception(
        "Error ${res.statusCode} Failed to load video episodes for $titles");
  }

  try {
    List<List<String>> episodesLists = [];

    List<dynamic> decodedData = json.decode(res.body);
    for (Map<String, dynamic> data in decodedData) {
      if (!data.containsKey("status") || !data.containsKey("data")) {
        throw Exception("Invalid metadata format from server.");
      }
      if (data["status"] != 200) {
        throw Exception("Error, returned status code ${data["status"]}");
      }

      List<String> episodeIndex = data["data"].cast<String>();
      episodesLists.add(episodeIndex);
    }
    return episodesLists;
  } catch (err) {
    print("Error parsing video episodes: $err");
    return [];
  }
}

/// Returns a [VideoPlayerController] for the specified [episode] of [title].
VideoPlayerController getNetworkVideo(String title, String episode) {
  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  return VideoPlayerController.networkUrl(
    Uri.parse(
        "http://$address:$port/public/${convertJWTToSignedFolder(jwt)}/video/$title/$episode"),
  );
}

/// Returns a [List] of available subtitles for the specified [episode] of
/// [title].
Future<List<String>> getSubtitleSelections(String title, String episode) async {
  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final http.Response res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointSubtitleSelections?title=$title&episode=$episode"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  switch (res.statusCode) {
    case 200:
      {
        return List<String>.from(json.decode(res.body));
      }
    case 204:
      {
        return [];
      }
    case 401:
      {
        throw Exception('Auth token has expired.');
      }
    case 500:
      {
        throw Exception('Server issue when asking for subtitles.');
      }
    default:
      {
        throw Exception('Bad Request.');
      }
  }
}

/// Returns a [Subtitles] object for the specified [episode] of [title] and
/// the specified [track].
Future<Subtitles> getNetworkSubtitles(
    String title, String episode, String track) async {
  // Get the address and Port and JWT from out cache
  final String? address = UserState().getServerAddress();
  final String? port = UserState().getServerPort();
  final String? jwt = UserState().getConnectionJWT();
  if (address == null || address.isEmpty) {
    throw Exception("No address found in cache.");
  }
  if (port == null || port.isEmpty) {
    throw Exception("No port found in cache.");
  }
  if (jwt == null || jwt.isEmpty) {
    throw Exception("No JWT found in cache.");
  }

  final http.Response res = await http.get(
    Uri.parse(
        "http://$address:$port/$endpointSubtitlesChewieFmt?title=$title&episode=$episode&track=$track"),
    headers: {
      "Authorization": "Bearer $jwt",
    },
  );

  switch (res.statusCode) {
    case 200:
      {
        List<Subtitle> subtitlesList = [];
        for (dynamic subtitles in json.decode(res.body)) {
          subtitlesList.add(Subtitle(
            index: subtitles["index"],
            start: Duration(milliseconds: subtitles["start_ms"]),
            end: Duration(milliseconds: subtitles["end_ms"]),
            text: subtitles["text"],
          ));
        }

        return Subtitles(subtitlesList);
      }
    case 401:
      {
        throw Exception('Auth token has expired.');
      }
    case 500:
      {
        throw Exception('Server issue when asking for subtitles.');
      }
    default:
      {
        throw Exception('Server issue when asking for subtitles.');
      }
  }
}
