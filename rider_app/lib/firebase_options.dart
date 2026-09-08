// File generated from the shared MartFood Firebase project.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqxMaQB3HCnXLOY7oMHZZo3NkoCHjCnVM',
    appId: '1:45361321160:android:ea488aa4e951b82ef241fd',
    messagingSenderId: '45361321160',
    projectId: 'martfood-app',
    databaseURL:
        'https://martfood-app-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'martfood-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBu6QGUlJKrywRVPx9065ukpOI6u6tKnlI',
    appId: '1:45361321160:ios:059d4157ae329d5af241fd',
    messagingSenderId: '45361321160',
    projectId: 'martfood-app',
    databaseURL:
        'https://martfood-app-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'martfood-app.firebasestorage.app',
    iosClientId:
        '45361321160-7gru3av7qtu11b177mu2ign5q12kg39r.apps.googleusercontent.com',
    iosBundleId: 'com.martfood.rider',
  );
}
