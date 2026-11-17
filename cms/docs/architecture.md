# Clinic Management System (CMS) — Architecture Design Document
**الإصدار:** 1.1 (متوافق مع وثيقة SRS v1.1)  
**التاريخ:** 2026-11-17  

---

## 1. System Architecture (المعمارية العامة للنظام)

يعتمد نظام **CMS** على معمارية **Hybrid Local + Cloud Architecture** تجمع بين العمل السحابي المركزي عبر **Firebase** والتشغيل المحلي المستمر داخل العيادة عبر **Local Clinic Server (Dart + SQLite/Drift)**، بحيث تستمر جميع العمليات الطبية والإدارية والمالية داخل العيادة عبر شبكة LAN حتى عند انقطاع الإنترنت بالكامل.

### 1.1 المكونات الرئيسية الثلاثة
1. **Flutter Multi-Platform Client (`cms/apps/clinic_app`)**:
   - **Windows Desktop**: مكاتب الاستقبال، السكرتارية، المحاسبة، الإدارة، وشاشة الانتظار المستقلة.
   - **Android**: الأطباء، التمريض، منسق المختبرات.
   - **Web**: لوحة الإدارة السحابية، التقارير المركزية، وبوابة المختبرات الخارجية.
   - **iOS / macOS**: مهيأ معمارياً عبر فصل واجهات المنصة (`Platform Gateway`).
2. **Local Clinic Server (`cms/apps/local_server`)**:
   - خدمة Dart مستقلة تعمل على جهاز Windows مخصص داخل العيادة على منفذ LAN آمن (HTTPS/TLS داخل الشبكة أو HTTP محلي مع توقيع الجلسات).
   - تضم: `Dart REST + WebSocket API`، قاعدة بيانات `SQLite` عبر `Drift ORM`، مدير ملفات محلي مشفر، محرك مزامنة ثنائي الاتجاه (`Outbox/Inbox Sync Worker`)، ونظام مصادقة محلي موثوق (`Offline Auth Cache` + `RBAC`).
3. **Firebase Cloud Backend (`cms/firebase`)**:
   - **Firebase Authentication**: إدارة الهوية والمصادقة المركزية و`Custom Claims`.
   - **Cloud Firestore**: قاعدة البيانات السحابية متعددة العيادات (`Multi-Tenant`).
   - **Firebase Storage**: حفظ ملفات PDF، نتائج التحاليل، صور الأشعة، المرفقات الطبية والإدارية (Private Bucket).
   - **Cloud Functions (Node.js/TypeScript)**: التحقق الخادمي من الصلاحيات، بوابة استقبال المزامنة (`syncIngest`)، المعاملات المالية الحساسة، تكامل المختبرات (`Webhooks / Portal`)، الإشعارات (`FCM`)، وسجل التدقيق غير القابل للتعديل.

### 1.2 تحليل التوافق التقني ومخاطر المنصات (Platform Compatibility Check)
وفق البند 5.1 من وثيقة SRS:
- **حزم FlutterFire على Windows Desktop**:
  - لا تدعم جميع حزم `FlutterFire` نظام Windows Desktop بشكل كامل ومستقر في كل الإصدارات (`firebase_messaging`, `firebase_crashlytics`, `firebase_app_check` لا تعمل أصيلاً على Windows؛ بينما `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` على Windows قد تتطلب C++ SDK أو تواجه قيود ربط).
  - **الحل الهندسي المعتمد**: تطبيق نمط **Repository + Transport Gateway Abstraction (`DataSourceGateway`)**:
    - داخل العيادة (Windows Desktop & Clinic LAN Android): يتصل تطبيق Flutter بـ **Local Clinic Server** عبر REST/WebSocket (ويقوم الخادم المحلي بالمزامنة مع السحابة).
    - في وضع السحابة المباشر (Web / Android خارج العيادة): يستخدم التطبيق طبقة `CloudGateway` (Firebase SDK على Android/Web أو Firebase REST/Functions Gateway عند الحاجة على Desktop).
- **ملاحظة بيئة التنفيذ الحالية (Environment Disclosure)**:
  - بيئة التطوير الحالية توفر `Node.js v22`, `TypeScript`, `Vite/React`, و`Firebase CLI`، ولا تحتوي على `Flutter SDK` أو `Dart SDK`. لذلك تم بناء كامل مشروع Flutter/Dart في مجلد `cms/` بالبنية والاعتماديات الدقيقة دون استبدال أي تقنية، مع توفير اختبارات TypeScript قابلة للتنفيذ فوراً لمنطق الخادم السحابي وقواعد المزامنة والصلاحيات، إضافة إلى واجهة ويب تفاعلية باللغة العربية RTL لتشغيل واختبار مسارات النظام في المعاينة الحية.

---

## 2. Component Diagram (مخطط المكونات)

```text
+-----------------------------------------------------------------------+
|                     CLINIC LAN (Offline-First)                        |
|                                                                       |
|  +-----------------------+       +-----------------------+            |
|  | Flutter Windows App   |       | Flutter Android App   |            |
|  | (Reception/Cashier/   |       | (Doctor / Nurse)      |            |
|  |  Waiting Display)     |       |                       |            |
|  +-----------+-----------+       +-----------+-----------+            |
|              | REST + WebSocket (LAN)        |                        |
|              +---------------+---------------+                        |
|                              v                                        |
|  +---------------------------------------------------------------+    |
|  |            Local Clinic Server (Dart - Windows Host)          |    |
|  |  +----------------+  +------------------+  +---------------+  |    |
|  |  | Local REST/WS  |  | Local Auth/RBAC  |  | Local File    |  |    |
|  |  | API Gateway    |  | Session Engine   |  | Vault         |  |    |
|  |  +-------+--------+  +--------+---------+  +-------+-------+  |    |
|  |          |                    |                    |          |    |
|  |          v                    v                    v          |    |
|  |  +---------------------------------------------------------+  |    |
|  |  |          SQLite + Drift ORM (Transactions)              |  |    |
|  |  |  Domain Tables + sync_outbox + sync_inbox + conflicts   |  |    |
|  |  +----------------------------+----------------------------+  |    |
|  |                               |                               |    |
|  |                  +------------v------------+                  |    |
|  |                  | Background Sync Worker  |                  |    |
|  |                  +------------+------------+                  |    |
|  +-------------------------------|-------------------------------+    |
+----------------------------------|------------------------------------+
                                   | HTTPS (REST / Cloud Functions / Firestore)
                                   | Resumes automatically when Internet is up
                                   v
+-----------------------------------------------------------------------+
|                       FIREBASE CLOUD BACKEND                          |
|                                                                       |
|  +----------------+  +------------------+  +-----------------------+  |
|  | Firebase Auth  |  | Cloud Functions  |  | Firebase Storage      |  |
|  | Custom Claims  |  | (Node.js / TS)   |  | Private Multi-Tenant  |  |
|  +-------+--------+  +--------+---------+  +-----------+-----------+  |
|          |                    |                        |              |
|          v                    v                        v              |
|  +---------------------------------------------------------------+    |
|  |         Cloud Firestore (Multi-Tenant + Security Rules)       |    |
|  |    /tenants/{tenantId}/...  +  /platform/...                  |    |
|  +---------------------------------------------------------------+    |
|                               ^                                       |
|                               | Authenticated Webhooks / Portal       |
|  +----------------------------+----------------------------------+    |
|  |   Flutter Web App (Cloud Admin / External Lab Portal)         |    |
|  +---------------------------------------------------------------+    |
+-----------------------------------------------------------------------+
```

---

## 3. Data Flow (تدفق البيانات)

### 3.1 رحلة المريض داخل العيادة (Online أو Offline)
1. **الاستقبال**: يبحث عن المريض (بالاسم/الهاتف/الرقم الطبي). عند عدم وجوده، ينشئ ملفاً جديداً عبر `Local API` -> معاملة Drift تحفظ في `local_patients` + تسجل حدثاً في `sync_outbox` + تنشئ سجل تدقيق `local_audit_logs`.
2. **الموعد والطابور**: يتم حجز موعد أو تسجيل الحضور مباشرة -> إصدار `QueueTicket` برقم يومي متسلسل (`Q-001`) -> بث حدث WebSocket فوري إلى شاشة الانتظار وجهاز الطبيب على شبكة LAN.
3. **التمريض والطبيب**: يفتح الطبيب الزيارة (`VIS-XXXXXX`) المستقلة عن ملف المريض -> تسجيل العلامات الحيوية، الشكوى، الفحص السريري، التشخيص -> حفظ كمسودة أو اعتماد نهائي (`finalized` مع قفل التعديل الصامت).
4. **المختبرات والوصفات**:
   - طلب فحص (`LAB-XXXXXX`) مع QR وطباعة -> إرسال الطلب للمختبر أو متابعته يدوياً.
   - عند وصول النتيجة (يدوياً PDF/صورة، أو بوابة المختبر، أو Webhook) -> ربطها بالطلب والزيارة والمريض -> إشعار الطبيب -> مراجعة الطبيب واعتمادها يدوياً (لا اعتماد آلي بدون مراجعة بشرية).
   - إصدار وصفة طبية (`RX-XXXXXX`) قابلة للطباعة مع توثيق أي تعديل أو إلغاء لاحق.
5. **المحاسبة والصندوق**:
   - إنشاء فاتورة مرتبطة بالزيارة -> **فصل رسوم المختبر الخارجي عن إيراد العيادة** افتراضياً ما لم توجد اتفاقية مالية موثقة.
   - تسجيل الدفعات عبر `paymentReference` فريد مانع للتكرار + سند قبض + إقفال وردية الصندوق اليومي.

---

## 4. Firestore Data Model (نموذج قاعدة البيانات السحابية)

راجع الملف التفصيلي: `docs/database_design.md`.
- جميع الكيانات تستخدم `UUID v4` مع حقول إلزامية:
  `id`, `tenantId`, `clinicId`, `branchId`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `schemaVersion`, `recordVersion`, `syncStatus`, `deletedAt` (Tombstone).
- المسارات الجذرية:
  - `/platform/administrators/{adminUid}`
  - `/platform/configuration/{configId}`
  - `/tenants/{tenantId}` (ملف العيادة + الإعدادات + الفروع + العضويات `/memberships/{uid}`)
  - جميع المجموعات الوظيفية تحت `/tenants/{tenantId}/...`: `patients`, `appointments`, `queue_tickets`, `visits`, `consultations`, `laboratories`, `medical_tests`, `lab_orders`, `lab_results`, `medications`, `prescriptions`, `documents`, `invoices`, `payments`, `expenses`, `cashbox_shifts`, `notifications`, `audit_logs`, `sync_conflicts`, `integrations`, `laboratory_events`.
- **حظر القوائم غير المحدودة**: لا تُخزن الزيارات أو التحاليل أو بنود الفواتير غير المحدودة داخل وثيقة واحدة؛ بل في مجموعات مستقلة أو `Subcollections` مع فهارس مركبة و`Pagination` (cursor-based).

---

## 5. Local Database Design (قاعدة البيانات المحلية SQLite + Drift)

- الجداول المحلية الـ 15 المذكورة في SRS §10 إضافة إلى الجداول المساندة (`local_users`, `local_laboratories`, `local_medical_tests`, `local_medications`, `local_expenses`, `local_cashbox_shifts`, `local_audit_logs`):
  - `local_patients`, `local_visits`, `local_appointments`, `local_queue_tickets`, `local_consultations`, `local_lab_orders`, `local_lab_results`, `local_prescriptions`, `local_invoices`, `local_payments`, `local_documents`, `sync_outbox`, `sync_inbox`, `sync_conflicts`, `sync_metadata`.
- **المعاملات (ACID Transactions)**: كل عملية حفظ تتضمن تحديث الجدول الأساسي + إدراج عملية `sync_outbox` + إدراج `local_audit_logs` داخل `db.transaction(...)` واحدة لمنع فقدان الترابط عند انقطاع الكهرباء.
- **التشفير المحلي**: دعم SQLCipher أو تشفير مستوى نظام التشغيل (BitLocker / DPAPI على Windows لحماية ملف قاعدة البيانات ومجلد المرفقات المحلية ومفاتيح الجلسات).

---

## 6. Authentication & Authorization (الهوية والصلاحيات)

- **السحابة**: Firebase Auth (Email/Password + MFA مستقبلاً) مع `Custom Claims` صادرة عن Cloud Functions (`tenantId`, `role`, `permissionsHash`, `branchIds`) + وثيقة عضوية `/tenants/{tenantId}/memberships/{uid}` للتحقق الفوري عند تعطيل الحساب.
- **العمل دون إنترنت (Offline Auth)**:
  - عند نجاح تسجيل الدخول الأول عبر الإنترنت، يصدر الخادم المحلي رمز جلسة موقعاً محلياً (`HMAC-SHA256` بمفتاح جهاز محفوظ في نظام التشغيل) مع تخزين `Argon2/PBKDF2` hash للتحقق عند انقطاع الإنترنت لفترة صلاحية قابلة للضبط (مثلاً 24–72 ساعة) قبل طلب تجديد سحابي.
- **الأدوار الـ 9 المعتمدة (RBAC)**:
  `super_admin`, `clinic_owner`, `clinic_manager`, `receptionist`, `doctor`, `nurse`, `accountant`, `lab_coordinator`, `staff`.
  - تُدمج صلاحيات `receptionist` و`secretary` افتراضياً في حساب الاستقبال بالنسخة الأولى مع أذونات منفصلة قابلة للتقسيم في أي وقت (`patients.write`, `documents.archive`, إلخ).
- **التحقق ثلاثي الطبقات**: في Flutter UI (لإخفاء/تعطيل الأزرار) + في Local Server Middleware / UseCase + في Firestore Rules وCloud Functions (المرجع الحاسم).

---

## 7. Synchronization Architecture (معمارية المزامنة الثنائية)

راجع الملف التفصيلي: `docs/sync_design.md`.
- **Outbox Pattern**: كل تغيير محلي يُسجل في `sync_outbox` بحقول: `operationId (UUID)`, `idempotencyKey`, `entityType`, `entityId`, `operation (create|update|delete)`, `baseVersion`, `payloadJson`, `status (pending|in_flight|synced|conflict|failed)`, `retryCount`, `nextRetryAt`.
- **Inbox Pattern**: التغييرات القادمة من Firestore/Cloud Functions تُسجل في `sync_inbox` حسب `lastSyncCursor` (serverTimestamp + operationId) مع فحص عدم التكرار.
- **منع Last-Write-Wins على البيانات الحساسة**:
  - إذا `remote.recordVersion > local.baseVersion` في السجلات الطبية (`consultations`, `visits`, `lab_results`, `prescriptions`) أو المالية (`invoices`, `payments`, `expenses`, `cashbox_shifts`) أو `patients`:
  - **يُمنع الكتابة فوق السجل بصمت**. تُحفظ النسختان في `sync_conflicts` بحالة `pending_review` ويُخطر الطبيب/المدير/المحاسب المخوّل لحل التعارض باختيار النسخة المعتمدة أو الدمج الموثق في سجل التدقيق.

---

## 8. Security Architecture (معمارية الأمان والخصوصية)

- **Zero-Trust Multi-Tenant**: لا يُقبل `tenantId` من العميل بمفرده أبداً؛ يتحقق الخادم وقواعد Firestore من وجود عضوية فعّالة للمستخدم (`membership.active == true`) داخل ذلك `tenantId`.
- **حماية الخصوصية (No PHI Leakage)**: يمنع إرسال أسماء المرضى أو أرقام هواتفهم أو تشخيصاتهم أو تحاليلهم إلى `Firebase Analytics`, `Crashlytics`, أو ملفات السجل التقني (`Logs`).
- **Private Storage**: مسار ملفات مقيد بـ `/tenants/{tenantId}/patients/{patientId}/visits/{visitId}/{documentId}` مع التحقق من `contentType` وحجم الملف ومنع الوصول العام.
- **عدم وجود أسرار في العميل**: مفاتيح `Firebase Admin SDK` و`Lab API Secrets` تُحفظ فقط في `Cloud Functions Secret Manager` وبيئة الخادم الموثوق.

---

## 9. Deployment Architecture (معمارية النشر والبيئات)

- **البيئات الثلاث**: `development` (Firebase Emulator + Local SQLite), `staging` (مشروع Firebase تجريبي), `production` (مشروع Firebase إنتاجي مع App Check ونسخ احتياطي مجدول).
- **نشر العيادة الواحدة**:
  1. جهاز Windows مخصص في الاستقبال يشغّل خدمة `cms_local_server.exe` (Windows Service) + قاعدة `cms_clinic.db` مع نسخ احتياطي مشفر يومي.
  2. أجهزة الاستقبال والمحاسبة تشغّل `cms_clinic.exe` (Windows) متصلة بـ `LAN IP`.
  3. جهاز الطبيب والتمريض يشغّل `cms_clinic.apk` (Android) متصلاً بالخادم المحلي عبر Wi-Fi الداخلي (أو بالسحابة عند العمل عن بُعد).
  4. المدير والمختبرات الخارجية يستخدمون نسخة Web المستضافة على `Firebase Hosting`.
