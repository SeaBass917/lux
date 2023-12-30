import 'package:flutter/material.dart';
import 'package:lux/style/stylesheet.dart';

class HomePageAppBar extends StatefulWidget {
  final String _title;
  final ValueChanged<String> onSelectionChanged;

  const HomePageAppBar(this._title, this.onSelectionChanged, {Key? key})
      : super(key: key);

  String getTitle() => _title;

  @override
  _HomePageAppBarState createState() => _HomePageAppBarState();
}

class _HomePageAppBarState extends State<HomePageAppBar> {
  // Constants
  final Icon _searchIcon = const Icon(Icons.search);
  final Icon _closeIcon = const Icon(Icons.close);
  Icon _currSearchBarIcon = const Icon(Icons.search);
  final TextEditingController _filter = TextEditingController();

  // Late Variables
  late final Widget _appBarTitleInit;
  late Widget _appBarTitle;

  void _searchPressed() {
    setState(() {
      if (_currSearchBarIcon.icon == Icons.search) {
        _currSearchBarIcon = _closeIcon;
        _appBarTitle = TextField(
          autofocus: true,
          textAlignVertical: TextAlignVertical.bottom,
          style: const TextStyle(
            fontSize: LuxStyle.textSizeH1,
            color: LuxStyle.textColorBright,
          ),
          controller: _filter,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 10.0),
            // prefixIcon: Icon(Icons.search),
            hintText: "Search...",
          ),
        );
      } else {
        _currSearchBarIcon = _searchIcon;
        _appBarTitle = _appBarTitleInit;
        _filter.clear();
      }
    });
  }

  /*
   * Class Main Methods
   */

  @override
  void initState() {
    super.initState();

    // Initialize the app title
    _appBarTitleInit = Text(
      widget.getTitle(),
      style: const TextStyle(
        fontSize: LuxStyle.textSizeMassive,
        color: LuxStyle.textDefaultColor,
      ),
    );
    _appBarTitle = _appBarTitleInit;

    // Attach the search text to the searchFilter string
    _filter.addListener(() {
      widget.onSelectionChanged(_filter.text);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      actions: [
        IconButton(
          icon: _currSearchBarIcon,
          onPressed: _searchPressed,
        )
      ],
      expandedHeight: 60.0,
      floating: true,
      snap: true,
      elevation: 50,
      title: _appBarTitle,
    );
  }
}
