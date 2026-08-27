# دليل بناء كارتك APK خطوة بخطوة

## الطريقة السهلة (بدون تثبيت Flutter محليًا) - GitHub
1. أنشئ حساب GitHub واعمل Repo جديد `kartek`
2. ارفع كل ملفات `كارتك/` إلى الريبو:
   ```powershell
   cd "C:\Users\NANDERASER\Desktop\كارتك"
   git init
   git add .
   git commit -m "kartek v1"
   git branch -M main
   git remote add origin https://github.com/USERNAME/kartek.git
   git push -u origin main
   ```
3. بعد الرفع: افتح تبويب Actions في GitHub -> سيعمل Build تلقائياً -> بعد 5-7 دقائق حمل الـ APK من Artifacts
4. قبل البناء ضع `google-services.json` الحقيقي في `android/app/` واعمل commit

## الطريقة المحلية (ويندوز)

### 1) تثبيت Flutter
- حمل من https://docs.flutter.dev/get-started/install/windows
- فك الضغط في `C:\flutter` وأضف `C:\flutter\bin` للـ PATH
- شغل:
  ```powershell
  flutter doctor
  ```

### 2) تجهيز المشروع
```powershell
cd "C:\Users\NANDERASER\Desktop\كارتك"

# هذا الأمر يولد مجلدات android/ios الناقصة (مهم جداً)
flutter create . --project-name kartek --org com.kartek --platforms android

# سيعيد توليد AndroidManifest - ارجع استبدله:
# انسخ AndroidManifest.xml الذي جهزناه (فيه label كارتك) فوق الجديد
# أو عدل label يدوياً إلى كارتك

flutter pub get
```

### 3) ربط Firebase
- كما في README.md -> حمل `google-services.json` وضعه في `android/app/google-services.json`
- شغل:
  ```powershell
  dart pub global activate flutterfire_cli
  flutterfire configure --project=kartek-app --platforms=android
  ```

### 4) تغيير اللوجو
- استبدل `assets/images/logo.png` بلوجو الخاص بك (512x512 PNG شفاف)
- شغل:
  ```powershell
  flutter pub run flutter_launcher_icons
  ```

### 5) بناء APK
```powershell
flutter build apk --release
# الناتج: build\app\outputs\flutter-apk\app-release.apk (حوالي 20-30 MB)

# نسخة مقسمة أخف:
flutter build apk --split-per-abi
# ينتج 3 ملفات: arm64-v8a, armeabi-v7a, x86_64
```

### 6) توقيع APK للنشر (اختياري)
```powershell
keytool -genkey -v -keystore kartek.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kartek
# ثم أنشئ android/key.properties
```
محتوى `android/key.properties`:
```
storePassword=كلمة_السر
keyPassword=كلمة_السر
keyAlias=kartek
storeFile=../kartek.jks
```

## تغيير اسم التطبيق أو الباقة
- الاسم: `android/app/src/main/AndroidManifest.xml` -> `android:label="كارتك"`
- الباقة: `android/app/build.gradle` -> `applicationId "com.kartek.app"` + في Firebase نفسه

## مشاكل شائعة
- `google-services.json missing` -> ضع الملف الحقيقي
- `checkSeamless failed` -> لازم داتا فودافون أو VPN على الموبايل
- `Firebase not initialized` -> تأكد من `flutterfire configure`
