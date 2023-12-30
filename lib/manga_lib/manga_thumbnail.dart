import 'package:flutter/material.dart';
import 'package:lux/manga_lib/manga_metadata.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:lux/server_interface.dart';

import 'manga_info_page.dart';

class MangaThumbnail extends StatelessWidget {
  // Constructor Prototype
  const MangaThumbnail({Key? key, required this.metaData}) : super(key: key);

  // Vars
  final MangaMetaData metaData;

  // Build
  @override
  Widget build(BuildContext context) {
    final String title = metaData.title!;
    final String author = metaData.author!;
    final thumbnailArt = getMangaThumbnailArt(title, 130.0, 200.25);

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
                      style: const TextStyle(
                        color: LuxStyle.textColorBright,
                      ),
                    ),
                    alignment: Alignment.topLeft,
                    height: 32,
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Container(
                    child: Text(
                      author,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: LuxStyle.textColorFade,
                      ),
                    ),
                    alignment: Alignment.topLeft,
                    height: 16,
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
            MaterialPageRoute(builder: (context) => MangaInfoPage(title)),
          );
        },
      ),
    );
  }
}
