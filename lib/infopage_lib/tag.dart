import 'package:flutter/material.dart';
import 'package:lux/style/stylesheet.dart';

class Tag extends StatelessWidget {
  const Tag(this._text, {Key? key, Color? color});

  final String _text;
  final Color? color = null;

  String capitalizeWords(String sentence) {
    List<String> words = sentence.split(' ');

    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      if (word.isEmpty) continue;
      words[i] = word[0].toUpperCase() + word.substring(1);
    }

    return words.join(' ');
  }

  Color getColor() {
    final i = _text.hashCode % LuxStyle.tagColorPalette.length;
    return LuxStyle.tagColorPalette[i];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: color ?? getColor(), // Set the border color
          width: 2.0, // Set the border width
        ),
        borderRadius: BorderRadius.circular(10.0), // Set the border radius
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
        child: Text(capitalizeWords(_text)),
      ),
    );
  }
}
