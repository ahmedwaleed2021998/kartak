# Kartak Admin Mobile - ahmed-hartak

لوحة تحكم أدمن للموبايل - نفس وظائف admin.py للكمبيوتر

DB: https://ahmed-hartak-default-rtdb.firebaseio.com/users.json

## البناء
```powershell
cd admin_mobile
flutter create . --org com.kartak --project-name kartak_admin --platforms android
flutter pub get
flutter build apk --release
```

أو ارفعه لنفس الريبو kartak وسيبني تلقائياً

## نفس المنطق:
- hash_password sha256
- get_google_timestamp
- register / renew / change_password / delete + list users + حسابات الأيام المتبقية
