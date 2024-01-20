import 'package:flutter/material.dart';
import 'package:expandable/expandable.dart';
import 'package:lux/manga_lib/manga_metadata.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:lux/std_lib/std.dart';

import '../server_interface.dart';
import 'manga_viewer.dart';

class MangaInfoPage extends StatefulWidget {
  final String _title;

  const MangaInfoPage(this._title, {Key? key}) : super(key: key);

  String getTitle() => _title;

  @override
  _MangaInfoPageState createState() => _MangaInfoPageState();
}

class _MangaInfoPageState extends State<MangaInfoPage> {
  /*
   * Constants
   */

  // TODO: Move these all config/resources.
  final ExpandableController _descriptionExpandableController =
      ExpandableController();
  final String _lastChapterButtonString = "Continue Reading...";
  final String _firstChapterButtonString = "Start Reading...";
  final String _markUnreadString = "Mark Unread";
  final String _downloadString = "Download";
  final String _infoString = "More Info";
  final double _bodyTextSize = 16;
  final double _titleTextSize = 26;

  /*
   * Async Data
   */
  // Index of chapter paths on the local server
  Map<String, List<String>> _chaptersIndex = {};
  List<String> _chaptersList = [];

  /*
   * Callback Methods
   */

  void hamburgerMenuCb(String choice) async {
    if (choice == "markUnread") {
      // Reset the read status for all chapters in this manga
      final String title = widget.getTitle();
      forEach(
          _chaptersList,
          ((chapter) =>
              UserState().setChapterReadStatus(title, chapter, false)));

      // Reset the "last Chapter Read" cache
      if (_chaptersList.isNotEmpty) {
        UserState().setLastChapter(title, _chaptersList[0]);
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
   * Class Support Methods
   */

  // Query the server for a list of chapters for a given title
  Future<List<String>> getChapterList() async {
    try {
      List<Map<String, List<String>>> resList =
          await getMangaChaptersByTitle([widget.getTitle()]);
      if (resList.isEmpty) throw Exception("Server sent empty list..?");

      // The server returns a list of lists, but we only requested one title
      // so we only need the first element
      _chaptersIndex = resList[0];

      // Sort the keys into an ordered list
      _chaptersList = _chaptersIndex.keys.toList()..sort();
    } catch (err) {
      return [];
    }

    // Read chapters from the index
    return _chaptersList;
  }

  /// Load the metadata from the server
  /// Call this in the initState()
  Future<MangaMetaData> getMetaData(String title) async {
    try {
      List<MangaMetaData> data = await getMangaMetaDataByTitles([title]);
      if (data.isEmpty) {
        // This scenario means between the previous page and this page
        // the title was deleted from the server.
        // Go back to the last page
        Navigator.pop(context);
      }

      // We only requested one title, so return the first element
      return data[0];
    } catch (err) {
      return MangaMetaData();
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
  ///      By: Author
  ///        (20XX)
  ///
  ///    Description....
  ///
  ///  [>] Continue Reading...
  /// ```
  Future<SliverList> constructInfoWidgetFuture() async {
    final String title = widget.getTitle();

    final MangaMetaData metaData = await getMetaData(title);

    final String author = metaData.author ?? "";
    final String artist = metaData.artist ?? "";
    final String yearStart = metaData.yearStart ?? "";
    final String yearEnd = metaData.yearEnd ?? "";
    final String description = metaData.description ?? "";

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8.0),
          child: getMangaCoverArt(title, 130.0, 240.25),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              (title.length > 20) ? title.replaceFirst(' ', '\n', 20) : title,
              style: TextStyle(
                fontSize: _titleTextSize,
                color: LuxStyle.textColorBright,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Center(
          child: Text(
            (author == artist) ? "By: $author" : "By: $author\n • $artist",
            style: TextStyle(
              color: LuxStyle.textDefaultColor,
              fontSize: _bodyTextSize,
            ),
          ),
        ),
        Center(
          child: Text(
            (yearEnd.isNotEmpty && yearStart != yearEnd)
                ? "($yearStart - $yearEnd)"
                : "($yearStart)",
            style: TextStyle(
              color: LuxStyle.textDefaultColor,
              fontSize: _bodyTextSize,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 16.0),
          child: GestureDetector(
            onTap: () => _descriptionExpandableController.toggle(),
            child: ExpandablePanel(
              collapsed: Text(
                description,
                style: TextStyle(
                  fontSize: _bodyTextSize,
                  color: LuxStyle.textDefaultColor,
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

  /// Create the future widget for the chapter list at the bottom of the screen
  /// ```
  ///  Manga X Vol 1 Chapter 1
  ///  Manga X Vol 1 Chapter 2
  ///  Manga X Vol 1 Chapter 3
  ///  ...
  /// ```
  Future<SliverList> constructChapterListWidgetFuture(context) async {
    // Get title for http request
    final String title = widget.getTitle();

    // Read chapters from the index
    List<String> chapters = [];
    try {
      chapters = await getChapterList();
    } catch (err) {
      print(err);
      chapters = [];
    }

    // Check the state for this user to see if they have read this title,
    // and if they did what chapter they read last
    // If they have not read any chapters, initialize to chapter 0
    // So our quick button starts on the first chapter
    final bool isTitleRead = any(_chaptersList,
        ((chapter) => UserState().getChapterReadStatus(title, chapter)));
    final String lastChapter = UserState().getLastChapter(title) ??
        ((_chaptersList.isNotEmpty) ? _chaptersList[0] : '');

    // Create a sliver list from the chapters
    return SliverList(
      delegate: SliverChildListDelegate(
        <Widget>[
          MaterialButton(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.playlist_play,
                  color: LuxStyle.actionColor0,
                  size: 42.0,
                ),
                Text(
                  (isTitleRead)
                      ? _lastChapterButtonString
                      : _firstChapterButtonString,
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
                  builder: (context) => MangaViewer(
                      title, lastChapter, _chaptersIndex, _chaptersList),
                ),
              ).then((value) => setState(() {}));
            },
          ),
          for (final String chapter in chapters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 1.0, 16.0, 1.0),
              child: MaterialButton(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    chapter.replaceAll('_', ' '),
                    style: TextStyle(
                        fontSize: LuxStyle.textSizeH1,
                        color: UserState().getChapterReadStatus(title, chapter)
                            ? LuxStyle.txtColorInactive
                            : LuxStyle.textDefaultColor),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MangaViewer(
                          title, chapter, _chaptersIndex, _chaptersList),
                    ),
                  ).then((value) => setState(() => {}));
                },
              ),
            )
        ],
      ),
    );
  }

  /*
   * Class Main Methods
   */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15.0,
        actions: [
          PopupMenuButton(
            onSelected: hamburgerMenuCb,
            itemBuilder: (BuildContext ctx) {
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: "markUnread",
                  child: Text(_markUnreadString),
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
      body: CustomScrollView(slivers: [
        FutureBuilder<SliverList>(
          future: constructInfoWidgetFuture(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return snapshot.data!;
            } else {
              return SliverList(delegate: SliverChildListDelegate([]));
            }
          },
        ),
        FutureBuilder<SliverList>(
          future: constructChapterListWidgetFuture(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return snapshot.data!;
            } else {
              return SliverList(delegate: SliverChildListDelegate([]));
            }
          },
        )
      ]),
      backgroundColor: LuxStyle.bgColor1,
    );
  }
}
