import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:lux/server_interface.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;

class VideoPlayer extends StatefulWidget {
  final String _title;
  final String _episodeCurrent;
  final List<String> _episodeList;
  final List<Color> palette;

  String getTitle() => _title;

  String getEpisode() => path
      .basenameWithoutExtension(File(_episodeCurrent).path)
      .replaceAll('_', ' ');

  String getEpisodeFile() => _episodeCurrent;

  List<String> getEpisodes() => _episodeList;

  String getEpisodeKey() => "$_title/$_episodeCurrent";

  const VideoPlayer(this._title, this._episodeCurrent, this._episodeList,
      {Key? key, List<Color>? palette})
      : palette = palette ??
            const [LuxStyle.bgColor1, LuxStyle.bgColor0, LuxStyle.bgColor1],
        super(key: key);

  @override
  _VideoPlayerState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  List<String> _subtitleSelections = [];
  Subtitles _videoPlayerSubtitles = Subtitles([]);

  final Duration retryStoreDelay = const Duration(seconds: 1);
  final Duration checkTimestampInterval = const Duration(seconds: 15);

  /// Save the last episode for this title to the system cache
  void storeEpisodeInfo() {
    // NOTE: We want the extension on the episode
    final String title = widget.getTitle();
    final String episode = widget._episodeCurrent;

    // Update the user state to reflect this most recent episode
    // If we fail, delay and try again 2 more times.
    // On failure 3, print final error and give up.
    UserState().setLastEpisode(title, episode).then((bool status) {
      if (status) return;

      // Retry attempt 1
      print("Failed to save last episode for \"$title\" episode"
          " \"$episode\". (1 Failure)");
      Timer(retryStoreDelay, () {
        UserState().setLastEpisode(title, episode).then((bool status1) {
          if (status1) return;

          // Retry attempt 2
          print("Failed to save last episode for \"$title\" episode"
              " \"$episode\". (2 Failure)");
          Timer(retryStoreDelay, () {
            UserState().setLastEpisode(title, episode).then((bool status2) {
              if (status2) return;

              // Retry attempt 3
              print("Failed to save last episode for \"$title\" episode"
                  " \"$episode\". (3 Failure)");
              print("Giving up on saving last episode for \"$title\" episode"
                  " \"$episode\".");
            });
          });
        });
      });
    });

    // Mark the episode as read
    // If we fail, delay and try again 2 more times.
    // On failure 3, print final error and give up.
    UserState()
        .setEpisodeWatchedStatus(title, episode, true)
        .then((bool status) {
      if (status) return;

      // Retry attempt 1
      print("Failed to mark episode $episode for \"$title\" as read."
          "(1 Failure)");
      Timer(retryStoreDelay, () {
        UserState()
            .setEpisodeWatchedStatus(title, episode, true)
            .then((bool status1) {
          if (status1) return;

          // Retry attempt 2
          print("Failed to mark episode $episode for \"$title\" as read."
              "(2 Failure)");
          Timer(retryStoreDelay, () {
            UserState()
                .setEpisodeWatchedStatus(title, episode, true)
                .then((bool status2) {
              if (status2) return;

              // Retry attempt 3
              print("Failed to mark episode $episode for \"$title\" as read."
                  "(3 Failure)");
              print(
                  "Giving up on marking episode $episode for \"$title\" as read.");
            });
          });
        });
      });
    });
  }

  void checkTimestampCb() {
    final int playerPositionSec =
        _videoPlayerController.value.position.inSeconds;
    UserState().setLastTimestampForEpisode(
      widget.getTitle(),
      widget._episodeCurrent,
      playerPositionSec,
    );

    Timer(checkTimestampInterval, checkTimestampCb);
  }

  @override
  void initState() {
    super.initState();

    final String title = widget.getTitle();
    final String episode = widget.getEpisode();
    final String episodeFilename = widget.getEpisodeFile();

    _videoPlayerController = getNetworkVideo(title, episodeFilename);

    final int playerLastPositionSec =
        UserState().getLastTimestampForEpisode(title, episode);
    _videoPlayerController.seekTo(Duration(seconds: playerLastPositionSec));

    getSubtitleSelections(title, episode)
        .then((List<String> subtitleSelections) {
      _subtitleSelections = subtitleSelections;

      if (subtitleSelections.isEmpty) return;

      // Select the default subtitles
      // TODO: Remember what the user selected for the next ep of this series.
      // TODO: If there is no info, try to make an informed guess based on the
      //       pattern of elections made by user.
      getNetworkSubtitles(title, episode, _subtitleSelections[0])
          .then((videoPlayerSubtitles) {
        setState(() => _videoPlayerSubtitles = videoPlayerSubtitles);
      }).catchError((error) {
        print("Error: $error");
      });
    }).catchError((error) {
      print(error);
    });

    storeEpisodeInfo();

    // Start the polling timer for updating the last known timestamp of this
    // episode
    Timer(checkTimestampInterval, checkTimestampCb);
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  Future<Widget> constructVideoPlayerFuture() async {
    try {
      await _videoPlayerController.initialize();
    } catch (err) {
      print(err);
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      subtitle: _videoPlayerSubtitles,
      autoPlay: true,
      looping: false,
    );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Chewie(
        controller: _chewieController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String episode = widget.getEpisode();

    return Scaffold(
      appBar: AppBar(
        title: Text(episode),
      ),
      body: FutureBuilder<Widget>(
        future: constructVideoPlayerFuture(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return snapshot.data!;
          } else {
            // Default Loading screen while we wait on the network content
            final width = MediaQuery.of(context).size.width;
            return SizedBox(
              width: width,
              height: (width * 9) / 16,
              child: Container(
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Text(
                        episode,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.fromLTRB(0, 12, 0, 12)),
                    Center(
                      child: (snapshot.hasError)
                          ? const Text(
                              "Failed to load",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
