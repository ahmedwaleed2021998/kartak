# كارتك - Kartek

تطبيق Android لشحن فكة ومارد من فودافون كاش - نقل كامل من السكريبت البايثون `كاش لحمو (1).py`

## المميزات
- 25 باقة (فكة 2.5 -> 26 جنيه + مارد)
- اتصال Seamless + Token + إرسال Order (نفس الـ API)
- تسجيل دخول Firebase (إيميل/باسوورد + Google)
- حفظ كل عملية في Firestore `users/{uid}/orders`
- سجل محلي + سجل سحابي

## 1) إعداد Firebase (5 دقائق)
1. https://console.firebase.google.com -> Add project -> `kartek-app`
2. Authentication -> Sign-in method -> فعل Email/Password + Google
3. Firestore Database -> Create -> Start in test mode
   - Rules مقترحة (بعد الاختبار):
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{uid}/{document=**} {
           allow read, write: if request.auth != null && request.auth.uid == uid;
         }
       }
     }
     ```
4. Project Settings -> General -> Your apps -> Android
   - Package: `com.kartek.app`
   - App nickname: `كارتك`
   - حمل `google-services.json` وضعه في `android/app/google-services.json`
5. ثبت FlutterFire CLI:
   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project=kartek-app --platforms=android
   ```
   سيولد `lib/firebase_options.dart` تلقائياً (استبدل الملف الحالي)

## 2) إضافة اللوجو
- ضع اللوجو الذي عندك باسم `assets/images/logo.png` (512x512 أو 1024x1024 PNG شفافة)
- ثم:
  ```powershell
  flutter pub get
  flutter pub run flutter_launcher_icons
  ```
  سيولد أيقونة التطبيق تلقائياً. اسم التطبيق مضبوط في `android/app/src/main/AndroidManifest.xml` -> `كارتك`

## 3) تشغيل
```powershell
flutter pub get
flutter run          # على موبايل/إميوليتور
flutter build apk --release   # ينتج android/app/build/outputs/flutter-apk/app-release.apk
# أو مقسمة أخف:
flutter build apk --split-per-abi
```

## 4) بدون تثبيت Flutter؟ (GitHub Actions)
- ارفع المشروع على GitHub
- Actions -> New workflow -> Flutter Build APK (جاهز)
- سيبني APK تلقائياً بدون تثبيت محلي

## هيكل المشروع
```
lib/
  main.dart                 # AuthGate
  firebase_options.dart     # ضع قيمك هنا
  services/
    vodafone_service.dart   # نفس منطق البايثون getSeamless/getToken/sendOrder
    firestore_service.dart  # حفظ السجل
  screens/
    login_screen.dart
    home_screen.dart
```

## ملاحظات
- لازم الموبايل على داتا فودافون أو VPN وإلا checkSeamless سيفشل
- الـ API headers نفس السكريبت الأصلي تماماً
