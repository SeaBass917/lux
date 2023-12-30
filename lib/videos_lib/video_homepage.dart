import 'package:flutter/material.dart';
import 'package:lux/homepage_lib/homepage_appbar.dart';

import 'package:lux/server_interface.dart';
import 'package:lux/homepage_lib/homepage.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:lux/videos_lib/video_metadata.dart';
import 'package:lux/videos_lib/video_thumbnail.dart';

class VideoHomepage extends Homepage {
  final BottomNavigationBar _botNavBar;

  @override
  String getTitle() => _title;

  @override
  BottomNavigationBar getBotNavBar() => _botNavBar;

  @override
  _VideoHomepageState createState() => _VideoHomepageState();

  final String _title = "Videos";

  const VideoHomepage(this._botNavBar, {Key? key})
      : super(_botNavBar, key: key);
}

class _VideoHomepageState extends State<VideoHomepage> {
  // For the search filter
  String _selectionsFilter = "";

  /// Return true if this media should be shown in the list. <br>
  /// Filters that can effect the media list:
  ///    - Search Filter
  ///    - NSFW filter
  bool doShowMedia(VideoMetaData metaData, bool isNSFWEnabled) {
    // Search bar filter
    if (!metaData.title!.toLowerCase().contains(_selectionsFilter)) {
      return false;
    }

    // NSFW Filter
    if (!isNSFWEnabled && metaData.nsfw! != false) {
      return false;
    }

    return true;
  }

  /// Sort the index in place
  /// NOTE: currently we just sort alphabetically
  ///       It is intended that later we will have other sort methods.
  ///       - Date
  ///       - Ascending/Descending variants
  void sortIndex(List<VideoMetaData> mediaIndex) {
    mediaIndex.sort((a, b) => a.title!.compareTo(b.title!));
  }

  /// Build a list of thumbnails from the server media list
  Future<SliverGrid> getVideoThumbnails() async {
    // Widget requires index and user prefs to load first
    List<VideoMetaData> videoIndex = [];
    try {
      // Wait for the manga list from server
      videoIndex = await getVideoIndex();

      // Sort incoming according to current sorting policy
      sortIndex(videoIndex);
    } catch (err) {
      print(err);
    }

    //
    bool isNSFWEnabled = UserState().getNSFWEnabledStatus();

    return SliverGrid.count(
      crossAxisCount: 3,
      childAspectRatio: 0.505,
      children: <Widget>[
        for (VideoMetaData videoMetaData in videoIndex)
          if (doShowMedia(videoMetaData, isNSFWEnabled))
            VideoThumbnail(metaData: videoMetaData)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          HomePageAppBar(
            widget.getTitle(),
            (value) {
              _selectionsFilter = value.toLowerCase();
              setState(() {});
            },
          ),
          FutureBuilder<SliverGrid>(
            future: getVideoThumbnails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                }
              }
              return SliverGrid.count(
                crossAxisCount: 1,
                children: const <Widget>[],
              );
            },
          )
        ],
      ),
      backgroundColor: const Color.fromRGBO(17, 17, 17, 1),
      bottomNavigationBar: widget.getBotNavBar(),
    );
  }
}
