import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('غير مدعوم');
    }
  }

  // ahmed-hartak - تم الربط تلقائياً من google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUzyV0L-0e-EW9egYcagSzrP_ke2dcGhg',
    appId: '1:3611925445:android:82363ac5b0a6fc1dd049ac',
    messagingSenderId: '3611925445',
    projectId: 'ahmed-hartak',
    storageBucket: 'ahmed-hartak.firebasestorage.app',
    databaseURL: 'https://ahmed-hartak-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBUzyV0L-0e-EW9egYcagSzrP_ke2dcGhg',
    appId: '1:3611925445:ios:REPLACE_IOS',
    messagingSenderId: '3611925445',
    projectId: 'ahmed-hartak',
    storageBucket: 'ahmed-hartak.firebasestorage.app',
    databaseURL: 'https://ahmed-hartak-default-rtdb.firebaseio.com',
    iosBundleId: 'com.kartak.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUzyV0L-0e-EW9egYcagSzrP_ke2dcGhg',
    appId: '1:3611925445:web:REPLACE_WEB',
    messagingSenderId: '3611925445',
    projectId: 'ahmed-hartak',
    authDomain: 'ahmed-hartak.firebaseapp.com',
    storageBucket: 'ahmed-hartak.firebasestorage.app',
    databaseURL: 'https://ahmed-hartak-default-rtdb.firebaseio.com',
  );
}
