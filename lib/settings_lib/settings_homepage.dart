import 'package:flutter/material.dart';

import 'package:lux/homepage_lib/homepage.dart';
import 'package:lux/homepage_lib/homepage_appbar.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:settings_ui/settings_ui.dart';

class SettingsHomepage extends Homepage {
  final BottomNavigationBar _botNavBar;

  @override
  String getTitle() => _title;

  @override
  BottomNavigationBar getBotNavBar() => _botNavBar;

  @override
  _SettingsHomepageState createState() => _SettingsHomepageState();

  final String _title = "Settings";

  const SettingsHomepage(this._botNavBar, {Key? key})
      : super(_botNavBar, key: key);
}

class _SettingsHomepageState extends State<SettingsHomepage> {
  // For the search filter
  String _selectionsFilter = "";

  // Boolean Settings
  bool _isNSFWEnabled = false;
  bool _isLightThemeEnabled = false;

  void toggleNSFW(bool value) {
    UserState().setNSFWEnabledStatus(value);
    setState(() {
      _isNSFWEnabled = value;
    });
  }

  void toggleLightTheme(bool value) {
    UserState().setLightThemeStatus(value);
    setState(() {
      _isLightThemeEnabled = value;
    });
  }

  @override
  void initState() {
    super.initState();

    _isNSFWEnabled = UserState().getNSFWEnabledStatus();
    _isLightThemeEnabled = UserState().getLightThemeStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 109,
            child: CustomScrollView(
              slivers: <Widget>[
                HomePageAppBar(
                  widget.getTitle(),
                  (value) {
                    _selectionsFilter = value.toLowerCase();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SettingsList(
              sections: [
                SettingsSection(
                  title: const Text('Common'),
                  tiles: <SettingsTile>[
                    if ('light theme'.contains(_selectionsFilter))
                      SettingsTile.switchTile(
                        onToggle: toggleLightTheme,
                        initialValue: _isLightThemeEnabled,
                        leading: const Icon(Icons.sunny),
                        title: const Text('Light Theme'),
                        enabled: true,
                      ),
                    if ('show nsfw'.contains(_selectionsFilter))
                      SettingsTile.switchTile(
                        onToggle: toggleNSFW,
                        initialValue: _isNSFWEnabled,
                        leading: const Icon(Icons.lock_open),
                        title: const Text('Show NSFW'),
                        enabled: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: const Color.fromRGBO(17, 17, 17, 1),
      bottomNavigationBar: widget.getBotNavBar(),
    );
  }
}
