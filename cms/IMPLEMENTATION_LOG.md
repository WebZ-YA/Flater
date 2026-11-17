# Implementation Log — Clinic Management System (CMS)

## 2026-11-17
### القرار 1: التعامل مع توافق FlutterFire على Windows Desktop
- **المشكلة**: حزم `firebase_messaging` و`firebase_crashlytics` و`firebase_app_check` وبعض ميزات `FlutterFire` لا تدعم Windows Desktop أصيلاً.
- **القرار المعماري**: فصل النقل الشبكي عبر `ClinicTransportGateway` في `clinic_app` بحيث تتصل أجهزة Windows Desktop وAndroid داخل العيادة بالخادم المحلي (`cms_local_server` على Dart) عبر REST + WebSocket، ويتولى الخادم المحلي المزامنة السحابية الآمنة.

### القرار 2: حالة بيئة التنفيذ (AI Studio Container)
- **الملاحظة**: البيئة الحالية تحتوي `Node.js v22`, `TypeScript`, `Vite`, و`Firebase CLI` ولا تحتوي `Flutter SDK` أو `Dart SDK`.
- **الإجراء**: عدم استبدال Flutter/Dart أو الادعاء بتشغيل `flutter test`. تم إنشاء كامل كود Flutter/Dart في `/cms/` حسب المواصفات، وتشغيل اختبارات Node/TypeScript الفعلية (`tsx --test`) على منطق المزامنة والفوترة، إضافة إلى تشغيل نسخة معاينة ويب عربية RTL تفاعلية على المنفذ `3000`.

### القرار 3: فصل رسوم المختبر الخارجي ومنع Last-Write-Wins الأعمى
- تم تنفيذ دالة `evaluateSyncOperation` ودالة `calculateInvoiceAllocation` في `firebase/functions/src/sync_engine.ts` مع اختبارات وحدة تتحقق من حفظ نسختي التعارض وإغلاق التعديل الصامت على الزيارات المعتمدة.
