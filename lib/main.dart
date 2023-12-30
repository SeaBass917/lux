import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lux/manga_lib/manga_homepage.dart';
import 'package:lux/settings_lib/settings_homepage.dart';
import 'package:lux/user_state_lib/user_state.dart';
import 'package:lux/videos_lib/video_homepage.dart';
import 'package:lux/style/stylesheet.dart';

void main() async {
  // Startup App
  runApp(const MyApp());

  // Initialize Singleton(s)
  UserState _ = UserState();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final bool isLightThemeEnabled = UserState().getLightThemeStatus();

    SystemUiOverlayStyle theme = isLightThemeEnabled
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    // Set the SystemUI to dark theme
    SystemChrome.setSystemUIOverlayStyle(theme);

    return MaterialApp(
      title: 'Lux',
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.dark,
        backgroundColor: const Color.fromRGBO(17, 17, 17, 1),
        // primaryColor: Colors.lightBlue[800],
        // accentColor: Colors.cyan[600],

        // Define the default font family.
        // fontFamily: 'Georgia',

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        // textTheme: const TextTheme(
        //   headline1: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
        //   headline6: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold),
        //   bodyText2: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
        // ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  final Map<String, IconData> titleIconLookup = {
    'Manga': Icons.book,
    'Videos': Icons.tv,
    'Music': Icons.music_note,
    'Images': Icons.image,
    'Settings': Icons.settings,
  };

  // @override
  // void initState() {
  //   super.initState();
  // }

  /// Keep waiting until the UserState() has finished initializing.
  /// Once cache is valid, setState() to rebuild the page.
  void waitUntilInitialized() {
    if (UserState().isCacheValid()) {
      setState(() {});
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), waitUntilInitialized);
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Let the user select what is shown in this list
    // i.e. this list will be set in settings
    final List<String> _titles = <String>[
      'Manga',
      'Videos',
      'Music',
      'Images',
      'Settings',
    ];

    // Build the nav bar
    BottomNavigationBar botNavBar = BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      items: [
        for (final String title in _titles)
          BottomNavigationBarItem(
            icon: Icon(titleIconLookup[title]),
            label: title,
          ),
      ],
      fixedColor: LuxStyle.actionColor0,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
    );

    // Start the timer that will wait until the cache is ready.
    // Once it detects that the cache is ready, it will setState()
    waitUntilInitialized();

    // In the meantime, show a loading screen
    if (!UserState().isCacheValid()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Loading...',
            style: TextStyle(
              fontSize: LuxStyle.textSizeH1,
              color: LuxStyle.textColorFade,
            ),
          ),
        ),
        body: const Column(
          children: <Widget>[
            Center(
              child: Text(
                'Loading...',
                style: TextStyle(
                  fontSize: LuxStyle.textSizeMassive,
                  color: LuxStyle.textColorFade,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromRGBO(17, 17, 17, 1),
        bottomNavigationBar: botNavBar,
      );
    }

    // Switch homepage based on current nav index
    switch (_titles[_currentIndex]) {
      case "Manga":
        {
          return MangaHomepage(botNavBar);
        }
      case "Videos":
        {
          return VideoHomepage(botNavBar);
        }
      case "Settings":
        {
          return SettingsHomepage(botNavBar);
        }
      default:
        {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _titles[_currentIndex],
                style: const TextStyle(
                  fontSize: LuxStyle.textSizeH1,
                  color: Colors.amber,
                ),
              ),
            ),
            body: Column(
              children: <Widget>[
                Center(
                  child: Text(
                    'ERROR! No handler in main for a(n) "${_titles[_currentIndex]}" page.',
                    style: const TextStyle(
                      fontSize: LuxStyle.textSizeMassive,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color.fromRGBO(17, 17, 17, 1),
            bottomNavigationBar: botNavBar,
          );
        }
    } // Switch
  }
}
