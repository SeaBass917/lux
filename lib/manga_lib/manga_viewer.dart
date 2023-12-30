import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:lux/user_state_lib/user_state.dart';

import '../server_interface.dart';

class MangaViewer extends StatefulWidget {
  final String _title;
  final String _chapter;
  final Map<String, List<String>> _chaptersIndex;
  final List<String> _chaptersList;

  String getTitle() => _title;

  String getChapter() => _chapter;

  Map<String, List<String>> getIndex() => _chaptersIndex;

  List<String> getPages() => _chaptersIndex[_chapter]!;

  List<String> getChapterList() => _chaptersList;

  const MangaViewer(
      this._title, this._chapter, this._chaptersIndex, this._chaptersList,
      {Key? key})
      : super(key: key);

  @override
  FullScreen createState() => FullScreen();
}

class FullScreen extends State<MangaViewer> {
  /*
   * Constants
   */
  final String pageStr = "Page";
  final Duration retryStoreDelay = const Duration(seconds: 1);

  /*
   * Controllers
   */

  final BouncingScrollPhysics _scrollPhysics = const BouncingScrollPhysics();
  late PageController _pageController;
  final PhotoViewScaleStateController _photoScaleController =
      PhotoViewScaleStateController();

  /*
   * Dynamic Page Elements
   */
  int _currentPage = 1;
  String _pageCountStr = "";

  /*
   * Used To manage FullScreen (Hide app bars)
   */
  bool _fullScreenEnabled = true;
  final double _appBarTopHeightMax = 60;
  final double _appBarBotHeightMax = 60;
  double _appBarTopHeight = 0;
  double _appBarBotHeight = 0;

  /// This one seems to be some sort of fullScreen state machine...
  /// We are clearly fighting the OS fullScreen a lot here
  bool _wasNavButtonPressed = false;

  /*
   * Pre-computed
   */
  String _prevChapter = "";
  String _nextChapter = "";

  /*
   * Async Data
   */
  late List<NetworkImage> _images;

  /*
   * Utilities
   */

  void disableFullScreen() {
    _fullScreenEnabled = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    setState(() {
      _appBarTopHeight = _appBarTopHeightMax;
      _appBarBotHeight = _appBarBotHeightMax;
    });
  }

  void enableFullScreen() {
    _fullScreenEnabled = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _appBarTopHeight = 0;
      _appBarBotHeight = 0;
    });
  }

  void preCacheBatch(int index, {int radius = 2}) {
    for (int i = index - radius; i <= index + radius; i++) {
      if (0 <= i && i < _images.length) {
        precacheImage(_images[i], context);
      }
    }
  }

  /// Update the string that displays the page counter
  /// NOTE: This should typically be a part of a setState() call.
  void setPageCountStr() {
    _pageCountStr = "$pageStr $_currentPage / ${_images.length - 2}";
  }

  /*
  * Navigation Method(s)
  */

  // Used in callbacks for chapter transition events
  void loadNewChapter(String chapter) {
    // Attach the next
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MangaViewer(
          widget._title,
          chapter,
          widget.getIndex(),
          widget.getChapterList(),
        ),
      ),
    );
  }

  /*
   * Initialization Methods
   */

  /// Download the images for this chapter.
  ///   - Network Images need to be pre-cached if we want fast loading
  ///   - A black page is appended and prepended to the list, to allow
  ///     users to scroll past the end, and us to react to that input.
  List<NetworkImage> getChapterPages() {
    // Get the server's local path to the chapter we are currently on
    final String title = widget.getTitle();
    final String chapter = widget.getChapter();
    final List<String> pages = widget.getPages();

    // Create all the network images for each page in the chapter
    // Pad the beginning with a dead page
    // and Pad the end with a dead page
    List<NetworkImage> imageUrls = [];
    imageUrls.add(getBlackPng());
    for (final String page in pages) {
      imageUrls.add(getMangaPage(title, chapter, page));
    }
    imageUrls.add(getBlackPng());

    return imageUrls;
  }

  /// Cache some useful data that requires any math/lookups,
  /// but we want ready ASAP
  ///    - _prevChapter
  ///    - _nextChapter
  void precomputeFields() {
    // Previous and Next Chapter titles
    final chapters = widget.getChapterList();
    final int i = chapters.indexOf(widget.getChapter());
    final int iPrev = i - 1;
    final int iNext = i + 1;
    _prevChapter = (0 <= iPrev) ? chapters[iPrev] : "";
    _nextChapter = (iNext < chapters.length) ? chapters[iNext] : "";
  }

  /// Save the last chapter for this title to the system cache
  void storeChapterInfo() {
    final String title = widget.getTitle();
    final String chapter = widget.getChapter();

    // Update the user state to reflect this most recent chapter
    // If we fail, delay and try again 2 more times.
    // On failure 3, print final error and give up.
    UserState().setLastChapter(title, chapter).then((bool status) {
      if (status) return;

      // Retry attempt 1
      print("Failed to save last chapter for \"$title\" chapter"
          " \"$chapter\". (1 Failure)");
      Timer(retryStoreDelay, () {
        UserState().setLastChapter(title, chapter).then((bool status1) {
          if (status1) return;

          // Retry attempt 2
          print("Failed to save last chapter for \"$title\" chapter"
              " \"$chapter\". (2 Failure)");
          Timer(retryStoreDelay, () {
            UserState().setLastChapter(title, chapter).then((bool status2) {
              if (status2) return;

              // Retry attempt 3
              print("Failed to save last chapter for \"$title\" chapter"
                  " \"$chapter\". (3 Failure)");
              print("Giving up on saving last chapter for \"$title\" chapter"
                  " \"$chapter\".");
            });
          });
        });
      });
    });

    // Mark the chapter as read
    // If we fail, delay and try again 2 more times.
    // On failure 3, print final error and give up.
    UserState().setChapterReadStatus(title, chapter, true).then((bool status) {
      if (status) return;

      // Retry attempt 1
      print("Failed to mark chapter $chapter for \"$title\" as read."
          "(1 Failure)");
      Timer(retryStoreDelay, () {
        UserState()
            .setChapterReadStatus(title, chapter, true)
            .then((bool status1) {
          if (status1) return;

          // Retry attempt 2
          print("Failed to mark chapter $chapter for \"$title\" as read."
              "(2 Failure)");
          Timer(retryStoreDelay, () {
            UserState()
                .setChapterReadStatus(title, chapter, true)
                .then((bool status2) {
              if (status2) return;

              // Retry attempt 3
              print("Failed to mark chapter $chapter for \"$title\" as read."
                  "(3 Failure)");
              print(
                  "Giving up on marking chapter $chapter for \"$title\" as read.");
            });
          });
        });
      });
    });
  }

  /*
   * Class Main Methods
   */

  @override
  void initState() {
    super.initState();

    enableFullScreen();

    // Fetch the pages(images) for this chapter
    _images = getChapterPages();

    // Run anything we want to pre-compute
    precomputeFields();

    storeChapterInfo();

    // Get the last known page for this chapter, and update the UI
    // This is also where Page controller is initialized
    _currentPage = UserState()
        .getLastPageForChapter(widget.getTitle(), widget.getChapter());
    _pageController = PageController(initialPage: _currentPage);
    setPageCountStr();
  }

  @override
  Widget build(BuildContext context) {
    preCacheBatch(_currentPage);
    return Scaffold(
      appBar: AppBar(
        elevation: 15.0,
        toolbarHeight: _appBarTopHeight,
        title: Text(widget._chapter),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          color: LuxStyle.textDefaultColor,
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: _scrollPhysics,
        pageController: _pageController,
        reverse: true,
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: _images[index],
            scaleStateController: _photoScaleController,
            onTapUp: (context, details, controllerValue) {
              // Toggle fullScreen
              if (_fullScreenEnabled) {
                disableFullScreen();
              } else {
                enableFullScreen();
              }
            },
          );
        },
        itemCount: _images.length,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 30.0,
            height: 30.0,
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        onPageChanged: (int pageNum) {
          // Hit the beginning, go to prev chapter
          // If no prev chapter exists notify user & return to first page
          if (pageNum == 0) {
            if (_prevChapter.isNotEmpty) {
              loadNewChapter(_prevChapter);
            } else {
              _pageController.jumpToPage(1);
            }
          }
          // Hit the end, go to next chapter
          // If no next chapter exists notify user & return to prev page
          else if (pageNum == _images.length - 1) {
            if (_nextChapter.isNotEmpty) {
              loadNewChapter(_nextChapter);
            } else {
              _pageController.jumpToPage(pageNum - 1);
            }
            // Nominal case
          } else {
            _currentPage = pageNum;

            // Store current page info locally
            UserState().setLastPageForChapter(
                widget.getTitle(), widget.getChapter(), _currentPage);

            // Pre cache the surrounding pages
            preCacheBatch(_currentPage);

            // Update the page count string
            setState(() => setPageCountStr());

            // Exit fullScreen
            if (!_fullScreenEnabled && !_wasNavButtonPressed) {
              enableFullScreen();
              _wasNavButtonPressed = false;
            }
          }
        },
      ),
      bottomNavigationBar: Container(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                onPressed: _nextChapter.isNotEmpty
                    ? () => loadNewChapter(_nextChapter)
                    : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton(
                iconSize: 64,
                padding: EdgeInsets.zero,
                onPressed: (_currentPage < _images.length - 2)
                    ? () {
                        _wasNavButtonPressed = true;
                        _pageController.jumpToPage(_currentPage + 1);
                      }
                    : null,
                icon: const Icon(
                  Icons.arrow_left_rounded,
                  size: 64,
                ),
              ),
              Text(
                _pageCountStr,
                style: const TextStyle(
                  color: LuxStyle.textColorBright,
                  fontSize: LuxStyle.textSizeH2,
                ),
              ),
              IconButton(
                iconSize: 64,
                padding: EdgeInsets.zero,
                onPressed: (1 < _currentPage)
                    ? () {
                        _wasNavButtonPressed = true;
                        _pageController.jumpToPage(_currentPage - 1);
                      }
                    : null,
                icon: const Icon(Icons.arrow_right_rounded),
              ),
              IconButton(
                iconSize: 36,
                padding: EdgeInsets.zero,
                onPressed: _prevChapter.isNotEmpty
                    ? () => loadNewChapter(_prevChapter)
                    : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
        height: _appBarBotHeight,
        color: Colors.grey,
      ),
    );
  }
}
