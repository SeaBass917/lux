import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:expandable/expandable.dart';
import 'package:lux/infopage_lib/tag.dart';
import 'package:lux/std_lib/std.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:lux/videos_lib/video_metadata.dart';
import 'package:lux/videos_lib/video_player.dart';
import 'package:path/path.dart' as path;
import 'package:palette_generator/palette_generator.dart';

import '../server_interface.dart';

class VideoInfoPage extends StatefulWidget {
  final String _title;

  const VideoInfoPage(this._title, {Key? key}) : super(key: key);

  String getTitle() => _title;

  @override
  _VideoInfoPageState createState() => _VideoInfoPageState();
}

class _VideoInfoPageState extends State<VideoInfoPage> {
  // Controllers
  final ExpandableController _descriptionExpandableController =
      ExpandableController();

  // Constants TODO: Move these all config/resources.
  final String _lastEpisodeButtonString = "Continue Watching...";
  final String _firstEpisodeButtonString = "Start Watching...";
  final String _markUnwatchedString = "Mark Unwatched";
  final String _downloadString = "Download";
  final String _infoString = "More Info";
  final double _bodyTextSize = 16;
  final double _titleTextSize = 32;

  List<String> _episodeList = [];

  final List<Color> _palette = [
    LuxStyle.bgColor1,
    LuxStyle.bgColor0,
    LuxStyle.bgColor1,
  ];

  /*
   * Class Support Methods
   */

  String addTitleNewlines(String title) {
    if (title.length > 16) title = title.replaceFirst(' ', '\n', 16);
    if (title.length > 32) title = title.replaceFirst(' ', '\n', 32);
    return title;
  }

  Color desaturateColor(Color originalColor, {double amount = 0.1}) {
    HSLColor hslColor = HSLColor.fromColor(originalColor);
    hslColor =
        hslColor.withSaturation((hslColor.saturation - amount).clamp(0.0, 1.0));
    return hslColor.toColor();
  }

  String titleClean(String title) {
    return path.basenameWithoutExtension(File(title).path).replaceAll('_', ' ');
  }

  // Query the server for a list of episodes for a given title
  Future<List<String>> getEpisodeList() async {
    try {
      List<List<String>> resList =
          await getVideoEpisodesByTitle([widget.getTitle()]);
      if (resList.isEmpty) throw Exception("Server sent empty list..?");

      _episodeList = resList[0]..sort();
    } catch (err) {
      return [];
    }

    return _episodeList;
  }

  /// Load the metadata from the server
  /// Call this in the initState()
  Future<dynamic> getMetaData(String title) async {
    try {
      final List<VideoMetaData> data = await getVideoMetaDataByTitle([title]);
      if (data.isEmpty) throw Exception("Server sent empty list..?");

      final VideoMetaData metadata = data[0];

      return metadata;
    } catch (err) {
      return VideoMetaData();
    }
  }

  /*
   * Callback Methods
   */

  void hamburgerMenuCb(String choice) async {
    if (choice == "markUnwatched") {
      // Reset the read status for all chapters in this manga
      final String title = widget.getTitle();
      forEach(
          _episodeList,
          ((episode) =>
              UserState().setEpisodeWatchedStatus(title, episode, false)));

      // Reset the "last Episode Watched" cache
      if (_episodeList.isNotEmpty) {
        UserState().setLastEpisode(title, _episodeList[0]);
      }

      setState(() {});
    } else if (choice == "download") {
      print("TODO: Implement the download feature.");
    } else if (choice == "info") {
      print("TODO: Implement the More Info.");
    } else {
      print("ERROR! No actions implemented for choice $choice");
    }
  }

  /*
   * Future Builder Methods
   */

  /// Create the future widget for the info at the top of the screen
  /// ```
  ///     +---------+
  ///     |         |
  ///     |   Art   |
  ///     |         |
  ///     +---------+
  ///        Title
  ///
  ///   By: Studio ○ Staff
  ///        (20XX)
  ///
  ///    Description....
  ///
  ///  [>] Start Watching...
  /// ```
  Future<SliverList> constructInfoWidgetFuture() async {
    final String title = widget.getTitle();
    final double screenWidth = MediaQuery.of(context).size.width;

    final VideoMetaData metaData = await getMetaData(title);
    final String studio = metaData.studio ?? "";
    final String staff = metaData.staff ?? "";
    final String yearStart = metaData.yearStart ?? "";
    final String description = metaData.description ?? "";

    final List<String> tagList = metaData.tags ?? [];

    final CachedNetworkImage thumbnail =
        getVideoCoverArt(title, width: screenWidth, height: 250);

    // Create a color palette based on the image
    try {
      PaletteGenerator pGen = await PaletteGenerator.fromImageProvider(
          thumbnail.getImageProvider());
      if (pGen.colors.isNotEmpty) {
        final int len = pGen.colors.length;
        final List<Color> colorList = pGen.colors.toList();

        _palette[0] =
            HSLColor.fromColor(colorList[0]).withLightness(0.22).toColor();
        _palette[1] = HSLColor.fromColor(colorList[1 % len])
            .withLightness(0.22)
            .toColor();
        _palette[2] = HSLColor.fromColor(colorList[2 % len])
            .withLightness(0.22)
            .toColor();
      }
    } catch (err) {
      _palette[0] = LuxStyle.bgColor1;
      _palette[1] = LuxStyle.bgColor0;
      _palette[2] = LuxStyle.bgColor1;
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        thumbnail,
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 8.0, 32.0, 0.0),
          child: Row(
            children: [
              Text(
                addTitleNewlines(title),
                style: TextStyle(
                  fontSize: _titleTextSize,
                  color: LuxStyle.textColorBright,
                ),
                textAlign: TextAlign.left,
              ),
              const Padding(padding: EdgeInsets.fromLTRB(4.0, 0, 0, 0)),
              Text(
                "($yearStart)",
                style: TextStyle(
                  color: LuxStyle.textColorFade,
                  fontSize: _bodyTextSize,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 0, 32.0, 4.0),
          child: Text(
            (studio == staff || staff.isEmpty) ? studio : "$studio • $staff",
            style: TextStyle(
              color: LuxStyle.textColorFade,
              fontSize: _bodyTextSize,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 8.0, 32.0, 4.0),
          child: Wrap(children: [
            for (final tag in tagList)
              Padding(
                padding: const EdgeInsets.fromLTRB(0.0, 0.0, 4.0, 4.0),
                child: Tag(
                  tag,
                ),
              )
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 4.0, 32.0, 16.0),
          child: GestureDetector(
            onTap: () => _descriptionExpandableController.toggle(),
            child: ExpandablePanel(
              collapsed: Text(
                description,
                style: TextStyle(
                  fontSize: _bodyTextSize,
                  color: LuxStyle.textColorFade,
                ),
                maxLines: 4,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
              expanded: Text(
                description,
                softWrap: true,
                style: TextStyle(
                  fontSize: _bodyTextSize,
                  color: LuxStyle.textDefaultColor,
                ),
              ),
              controller: _descriptionExpandableController,
            ),
          ),
        ),
      ]),
    );
  }

  /// Create the future widget for the episode list at the bottom of the screen
  /// ```
  ///  Show X Season 1 Episode 1
  ///  Show X Season 1 Episode 2
  ///  Show X Season 1 Episode 3
  ///  ...
  /// ```
  Future<SliverList> constructEpisodeListWidgetFuture(context) async {
    // Get title for http request
    final String title = widget.getTitle();

    // Read chapters from the index
    List<String> episodes = [];
    try {
      episodes = await getEpisodeList();
    } catch (err) {
      print(err);
      // No-op
    }

    // Check the state for this user to see if they have read this title,
    // and if they did what chapter they read last
    // If they have not read any chapters, initialize to chapter 0
    // So our quick button starts on the first chapter
    final bool isTitleWatched = any(episodes,
        ((episode) => UserState().getEpisodeWatchedStatus(title, episode)));
    final String lastEpisode = UserState().getLastEpisode(title) ?? episodes[0];

    // Create a sliver list from the chapters
    return SliverList(
      delegate: SliverChildListDelegate(
        <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  desaturateColor(_palette[0]),
                  desaturateColor(_palette[1]),
                  desaturateColor(_palette[2]),
                ],
              ),
            ),
            child: MaterialButton(
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.playlist_play,
                      color: LuxStyle.actionColor0,
                      size: 42.0,
                    ),
                    Text(
                      (isTitleWatched)
                          ? _lastEpisodeButtonString
                          : _firstEpisodeButtonString,
                      style: const TextStyle(
                        fontSize: LuxStyle.textSizeH1,
                        color: LuxStyle.textDefaultColor,
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayer(
                        title,
                        lastEpisode,
                        _episodeList,
                        palette: _palette,
                      ),
                    ),
                  ).then((value) => setState(() {}));
                }),
          ),
          for (final String episode in episodes)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    desaturateColor(_palette[0]),
                    desaturateColor(_palette[1]),
                    desaturateColor(_palette[2]),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 1.0, 16.0, 1.0),
                child: MaterialButton(
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      titleClean(episode),
                      style: TextStyle(
                          fontSize: LuxStyle.textSizeH1,
                          color: UserState()
                                  .getEpisodeWatchedStatus(title, episode)
                              ? LuxStyle.txtColorInactive
                              : LuxStyle.textDefaultColor),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayer(
                          title,
                          episode,
                          _episodeList,
                          palette: _palette,
                        ),
                      ),
                    ).then((value) => setState(() {}));
                  },
                ),
              ),
            )
        ],
      ),
    );
  }

  Future<Stack> constructScaffoldBodyFuture(context) async {
    SliverList infoWidget = await constructInfoWidgetFuture();
    SliverList episodeList = await constructEpisodeListWidgetFuture(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _palette[0],
                _palette[1],
                _palette[2],
              ],
            ),
          ),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.black,
                height: MediaQuery.of(context).padding.top,
              ),
            ),
            infoWidget,
            episodeList,
          ]),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              PopupMenuButton(
                onSelected: hamburgerMenuCb,
                itemBuilder: (BuildContext ctx) {
                  return <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: "markUnwatched",
                      child: Text(_markUnwatchedString),
                    ),
                    PopupMenuItem<String>(
                      value: "download",
                      child: Text(_downloadString),
                    ),
                    PopupMenuItem<String>(
                      value: "info",
                      child: Text(_infoString),
                    ),
                  ];
                },
              ),
            ],
          ),
        )
      ],
    );
  }

  /*
   * Class Main Methods
   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Widget>(
        future: constructScaffoldBodyFuture(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return snapshot.data!;
          } else {
            return Container();
          }
        },
      ),
      backgroundColor: LuxStyle.bgColor1,
    );
  }
}
