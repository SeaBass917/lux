import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lux/auth_lib/auth_utils.dart';
import 'package:lux/server_interface.dart';
import 'package:lux/style/stylesheet.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:lux/user_state_lib/user_state.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Controllers
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Mange the keyboard state
  StreamSubscription<bool>? _keyboardSubscription;
  late bool _keyBoardVisible;

  // Ensure errors only pop up after the user has started entering text
  bool _doValidationsOnIP = false;
  bool _doValidationsOnPassword = false;

  // Used to toggle the loading indicator
  bool _isLoading = false;

  // Used to move through the form
  final _focusIP = FocusNode();
  final _focusPassword = FocusNode();

  String _requestErrorString = "";

  @override
  void initState() {
    super.initState();

    // Setup the controller that monitors the Keyboard visibility state
    var kbVisController = KeyboardVisibilityController();
    _keyBoardVisible = kbVisController.isVisible;
    _keyboardSubscription = kbVisController.onChange.listen((bool visible) {
      setState(() {
        _keyBoardVisible = visible;
      });
    });
  }

  @override
  void dispose() {
    _keyboardSubscription?.cancel();
    _ipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handler for the User clicked Connect button event.
  ///  - Validates the IP and Password fields.
  ///  - If valid, then attempt to connect to the server.
  void connectCb() async {
    // Run the validations on the IP and Password fields.
    setState(() {
      _doValidationsOnIP = true;
      _doValidationsOnPassword = true;
    });

    // Read the IP and Password fields.
    final String ip = _ipController.text.trim();
    final String pwd = _passwordController.text.trim();

    // If there are any validation errors, then don't attempt to connect.
    if (validateIP(ip) != null || validatePassword(pwd) != null) {
      return;
    }

    // Start up the spinner.
    setState(() {
      _isLoading = true;
    });

    // Before connecting to the server, we need the pepper for password hashing.
    // Check to see if we already have the pepper stored in the
    // shared preferences.
    String? pepper = UserState().getPepper();

    // If we don't have the pepper, then we need to get it from the server.
    // Query the get pepper endpoint.
    if (pepper == null) {
      try {
        pepper = await getPepperFromServer(ip, serverPort);
        UserState().setPepper(pepper);
      } catch (e) {
        // If we failed to get pepper from server,
        // then display the error message.
        setState(() {
          _requestErrorString = "Server not responding.";
        });
      }
    }

    // If we still don't have the pepper, then we can't connect to the server.
    if (pepper == null) {
      // Kill the spinner.
      _isLoading = false;
      setState(() {});
      return;
    }

    // Attempt to connect to the server.
    try {
      // Get the jwt token from the server.
      final String jwt = await getJWTFromServer(ip, serverPort, pwd, pepper);

      // If we got a jwt token, then store it in the shared preferences.
      if (jwt.isNotEmpty) {
        UserState().setServerAddress(ip, serverPort);
        UserState().setConnectionJWT(jwt);

        // Close the auth page.
        Navigator.pop(context);
      }
      // If we didn't get a jwt token, then the server responded we just
      // gave them the wrong password.
      else {
        _requestErrorString = "Incorrect password.";
      }
    } catch (e) {
      // If we failed to get the jwt token from the server,
      // then display the error message.
      _requestErrorString = "Server not responding.";
    }

    // Kill the spinner.
    _isLoading = false;
    setState(() {});
  }

  /// Handler for the ip field submitted event.
  ///   - If ip is valid, focuses the next menu option (password).
  ///   - Enable validation checks on this box.
  void ipFieldSubmittedCb(String v) {
    // Shift the focus to the next form, unless there are validation errors.
    // If there are validation errors, then we want to stay on this form.
    FocusScope.of(context).requestFocus(
        (validateIP(_ipController.text.trim()) == null)
            ? _focusPassword
            : _focusIP);

    // Update the internal state to enable validation checks on this box.
    setState(() {
      _doValidationsOnIP = true;
    });
  }

  /// Handler for the password field submitted event.
  ///   - If password is valid, de-focuses all menus.
  ///   - Enable validation checks on this box.
  void passwordFieldSubmittedCb(String v) {
    // If password is good, then we want to de-focus
    // If password is bad, then we want to stay on this form.
    final String pwd = _passwordController.text.trim();
    final bool isPwdValid = validatePassword(pwd) == null;
    if (isPwdValid) {
      _focusPassword.unfocus();
    } else {
      FocusScope.of(context).requestFocus(_focusPassword);
    }

    // Enable validation checks on this box, now that it has been populated.
    setState(() {
      _doValidationsOnPassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 100, 0, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Visibility(
              visible: !_keyBoardVisible,
              child: const Column(
                children: [
                  Text("Connection\nSetup",
                      style: TextStyle(
                          color: LuxStyle.textColorBright, fontSize: 52),
                      textAlign: TextAlign.center),
                  SizedBox(height: 10.0),
                  Text("Your media awaits.",
                      style: TextStyle(
                          color: LuxStyle.textColorBright,
                          fontSize: LuxStyle.textSizeH2),
                      textAlign: TextAlign.center),
                  SizedBox(height: 25.0),
                ],
              )),
          Text(
            _requestErrorString,
            style: const TextStyle(
                color: Colors.red,
                fontSize: LuxStyle.textSizeH2,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: TextFormField(
              focusNode: _focusIP,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: ipFieldSubmittedCb,
              autocorrect: false,
              controller: _ipController,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.wifi, color: LuxStyle.textColorFade),
                errorText: _doValidationsOnIP
                    ? validateIP(_ipController.text.trim())
                    : null,
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: LuxStyle.textColorBright),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: LuxStyle.actionColor0),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                hintText: "IP",
                // filled: true,
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: TextFormField(
              focusNode: _focusPassword,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: passwordFieldSubmittedCb,
              autocorrect: false,
              obscureText: true,
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: "Password",
                prefixIcon:
                    const Icon(Icons.lock_open, color: LuxStyle.textColorFade),
                errorText: _doValidationsOnPassword
                    ? validatePassword(_passwordController.text.trim())
                    : null,
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: LuxStyle.textColorBright),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: LuxStyle.actionColor0),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                // filled: true,
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: GestureDetector(
                onTap: connectCb,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: LuxStyle.actionColor0,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Center(
                      child: Text(
                    "Connect",
                    style: TextStyle(
                      color: LuxStyle.textColorBright,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )),
                )),
          ),
          _isLoading
              ? const SizedBox(height: 31.75)
              : const SizedBox(height: 100.0),
          Visibility(
            visible: _isLoading,
            child: const Center(child: CircularProgressIndicator()),
          ),
          _isLoading
              ? const SizedBox(height: 31.75)
              : const SizedBox(height: 0.0),
        ],
      ),
    );
  }
}
