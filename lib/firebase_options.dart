import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC318o7mu7NT8HdQ2LDm8CFQt0F3mY_14M',
    authDomain: 'fufaji-online-business.firebaseapp.com',
    databaseURL: 'https://fufaji-online-business-default-rtdb.firebaseio.com',
    projectId: 'fufaji-online-business',
    storageBucket: 'fufaji-online-business.firebasestorage.app',
    messagingSenderId: '126709583600',
    appId: '1:126709583600:web:2dc754e7782aeeb7d5bc35',
    measurementId: 'G-PDP66TX9R1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC7-ZBMsqkSux7H2bS44eOPCqquwIYZ4-c',
    appId: '1:126709583600:android:e6ad41f7d3dfa4f0d5bc35',
    messagingSenderId: '126709583600',
    projectId: 'fufaji-online-business',
    storageBucket: 'fufaji-online-business.firebasestorage.app',
    databaseURL: 'https://fufaji-online-business-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-project',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_APP_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-project',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_APP_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-project',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_APP_ID',
  );
}
