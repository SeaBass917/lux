import 'package:flutter/material.dart';
import 'package:lux/auth_lib/auth_page.dart';
import 'package:lux/homepage_lib/homepage.dart';
import 'package:lux/homepage_lib/homepage_appbar.dart';
import 'package:lux/manga_lib/manga_metadata.dart';

import 'package:lux/server_interface.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/manga_lib/manga_thumbnail.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:top_modal_sheet/top_modal_sheet.dart';

@immutable
class MangaHomepage extends Homepage {
  final BottomNavigationBar _botNavBar;

  @override
  String getTitle() => title;

  @override
  BottomNavigationBar getBotNavBar() => _botNavBar;

  @override
  _MangaHomepageState createState() => _MangaHomepageState();

  final String title = "Manga";

  const MangaHomepage(this._botNavBar, {Key? key})
      : super(_botNavBar, key: key);
}

class _MangaHomepageState extends State<MangaHomepage> {
  /*
   * Class Members
   */

  // Dynamics
  String _selectionsFilter = "";

  /*
   * Class Support Methods
   */

  /// Return true if this media should be shown in the list. <br>
  /// Filters that can effect the media list:
  ///    - Search Filter
  ///    - NSFW filter
  bool doShowMedia(MangaMetaData mangaMetaData, bool isNSFWEnabled) {
    // Search bar filter
    if (!mangaMetaData.title!.toLowerCase().contains(_selectionsFilter)) {
      return false;
    }

    // NSFW Filter
    if (!isNSFWEnabled && mangaMetaData.nsfw! != false) {
      return false;
    }

    return true;
  }

  /// Sort the index in place
  /// NOTE: currently we just sort alphabetically
  ///       It is intended that later we will have other sort methods.
  ///       - Date
  ///       - Ascending/Descending variants
  void sortIndex(List mediaIndex) {
    mediaIndex.sort((a, b) => a.title.compareTo(b.title));
  }

  /// Build a list of thumbnails from the server media list
  Future<SliverGrid> getMangaThumbnails() async {
    // Widget requires index and user preferences to load first
    List<MangaMetaData> mangaIndex = <MangaMetaData>[];
    try {
      // Wait for the manga list from server
      mangaIndex = await getMangaIndex();

      // Sort incoming according to current sorting policy
      sortIndex(mangaIndex);
    } catch (err) {
      // Prompt the user with the auth page
      await showTopModalSheet<String?>(context, const AuthPage());
    }

    //
    final bool isNSFWEnabled = UserState().getNSFWEnabledStatus();

    // Build the grid of manga selections
    return SliverGrid.count(
      crossAxisCount: 3,
      childAspectRatio: 0.505,
      children: <Widget>[
        for (var mangaMetaData in mangaIndex)
          if (doShowMedia(mangaMetaData, isNSFWEnabled))
            MangaThumbnail(metaData: mangaMetaData)
      ],
    );
  }

  /*
   * Class Main Methods
   */

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
            future: getMangaThumbnails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                return snapshot.data!;
              } else {
                // Return empty if there are any issues in communication
                return SliverGrid.count(
                  crossAxisCount: 1,
                  children: const <Widget>[],
                );
              }
            },
          )
        ],
      ),
      backgroundColor: LuxStyle.bgColor0,
      bottomNavigationBar: widget.getBotNavBar(),
    );
  }
}
