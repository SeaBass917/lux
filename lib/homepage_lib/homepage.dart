import 'package:flutter/material.dart';

@immutable
abstract class Homepage extends StatefulWidget {
  // ignore: unused_field
  final BottomNavigationBar _botNavBar;

  const Homepage(this._botNavBar, {Key? key}) : super(key: key);

  String getTitle();
  BottomNavigationBar getBotNavBar();
}
