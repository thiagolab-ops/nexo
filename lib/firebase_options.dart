import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyALzMvqCNVpDs9OYlzK3skkcyop8EYjl2w',
    appId: '1:1008883723814:web:e7abba00f2a076c1dc40e7',
    messagingSenderId: '1008883723814',
    projectId: 'nexo-ee9a8',
    authDomain: 'nexo-ee9a8.firebaseapp.com',
    storageBucket: 'nexo-ee9a8.firebasestorage.app',
    measurementId: 'G-HS1MY968S2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAshxQm3TvbVQOi_73NmKux6hgqyuAJHFA',
    appId: '1:1008883723814:android:bd72807faa56ba12dc40e7',
    messagingSenderId: '1008883723814',
    projectId: 'nexo-ee9a8',
    storageBucket: 'nexo-ee9a8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAAh_r9sn0owbzynXKc7QHCFXNNwa76Zg',
    appId: '1:1008883723814:ios:fd0a1dc4c479971adc40e7',
    messagingSenderId: '1008883723814',
    projectId: 'nexo-ee9a8',
    storageBucket: 'nexo-ee9a8.firebasestorage.app',
    iosClientId: '1008883723814-agh2rg5r6lm33at031c0kalmqer61l0m.apps.googleusercontent.com',
    iosBundleId: 'com.example.nexo',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyALzMvqCNVpDs9OYlzK3skkcyop8EYjl2w",
    appId: "1:1008883723814:ios:SUA_CONFIG_MACOS",
    messagingSenderId: "1008883723814",
    projectId: "nexo-ee9a8",
    storageBucket: "nexo-ee9a8.firebasestorage.app",
    iosBundleId: "com.example.nexo",
  );
}