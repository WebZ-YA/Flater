# Clinic Management System (CMS) — Deployment & Operations Guide

## 1. المتطلبات المسبقة على جهاز التطوير / الخادم
- Flutter SDK `>= 3.24.0` وDart SDK `>= 3.5.0`
- Node.js `v22+` وFirebase CLI
- SQLite3 / Visual Studio Build Tools (لنظام Windows Desktop)

## 2. تشغيل الخادم المحلي داخل العيادة (Windows LAN Server)
```bash
cd cms/apps/local_server
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run bin/server.dart
```
- يعمل على المنفذ `8085` (REST + WebSocket `/ws/lan`).
- متغيرات البيئة:
  - `CMS_LOCAL_DB_PATH`: مسار ملف `cms_clinic_local.db`
  - `CMS_LOCAL_HMAC_SECRET`: مفتاح توقيع الجلسات المحلية (لا يُحفظ في المستودع)
  - `CMS_LOCAL_STORAGE_DIR`: مجلد المرفقات المحلية المشفر
  - `CMS_CLOUD_SYNC_URL`: رابط دالة `syncIngest` السحابية

## 3. تشغيل تطبيق Flutter
```bash
cd cms/apps/clinic_app
flutter pub get
# Windows Desktop (Reception / Admin / Cashier)
flutter run -d windows --dart-define=CMS_ENV=development --dart-define=CMS_LOCAL_URL=http://127.0.0.1:8085
# Android (Doctor / Nurse)
flutter run -d android --dart-define=CMS_ENV=development --dart-define=CMS_LOCAL_URL=http://<SERVER_LAN_IP>:8085
# Web (Cloud Admin / External Lab Portal)
flutter run -d chrome --dart-define=CMS_ENV=staging
```

## 4. نشر خدمات Firebase السحابية
```bash
cd cms/firebase
cd functions && npm install && npm run build && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## 5. النسخ الاحتياطي والاستعادة
- يُوصى بأخذ نسخة احتياطية يومية مشفرة من `cms_clinic_local.db` ومجلد `local_vault/` إلى وسائط تخزين منفصلة، مع تفعيل النسخ الاحتياطي المجدول في Firestore.
