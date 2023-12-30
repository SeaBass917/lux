import 'package:flutter/material.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/server_interface.dart';
import 'package:lux/videos_lib/video_metadata.dart';

import 'video_info_page.dart';

class VideoThumbnail extends StatelessWidget {
  // Constructor Prototype
  const VideoThumbnail({Key? key, required this.metaData}) : super(key: key);

  // Vars
  final VideoMetaData metaData;

  // Build
  @override
  Widget build(BuildContext context) {
    final String title = metaData.title ?? "";
    final thumbnailArt = getVideoThumbnailArt(title, 130.0, 200.25);

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: RawMaterialButton(
        child: Column(
          children: <Widget>[
            thumbnailArt,
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                children: <Widget>[
                  Container(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    alignment: Alignment.topLeft,
                    height: 32,
                  ),
                ],
              ),
            ),
          ],
        ),
        fillColor: LuxStyle.bgColor1,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VideoInfoPage(title)),
          );
        },
      ),
    );
  }
}
