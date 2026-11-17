# Clinic Management System (CMS) — Hybrid Synchronization Design

## 1. المبادئ الحاكمة للمزامنة
1. **Local-First Durability**: في وضع العيادة، تُكتب كل عملية في `SQLite/Drift` داخل معاملة واحدة (`Transaction`) تشمل السجل + سجل `sync_outbox` + سجل `local_audit_logs`.
2. **Idempotency**: كل عملية تملك `operationId (UUID)` و`idempotencyKey` فريداً. إرسال نفس العملية مرتين إلى السحابة نتيجة انقطاع الشبكة يعيد النتيجة نفسها دون تكرار سجل أو فاتورة أو دفعة.
3. **No Blind Last-Write-Wins (LWW)**:
   - الكيانات الطبية (`consultations`, `visits`, `lab_results`, `prescriptions`, `patients`) والمالية (`invoices`, `payments`, `expenses`, `cashbox_shifts`) **محمية من LWW الأعمى**.
   - إذا اختلف `baseVersion` المحلي عن `recordVersion` السحابي الحالي، تُرفض الكتابة المباشرة، ويُنشأ سجل تعارض في `sync_conflicts` بحالتين كاملتين (`localSnapshot`, `remoteSnapshot`) ويُرفع تنبيه لمراجعة الطبيب أو المدير أو المحاسب المخوّل.
4. **Tombstones للحذف الآمن**: السجلات المسموح بإزالتها (مثل مسودة غير معتمدة أو عنصر قائمة انتظار ملغى قبل البدء) تُعلّم بـ `deletedAt` ولا تُمحى فيزيائياً قبل مزامنة الإزالة. السجلات الطبية والمالية المعتمدة لا تُحذف مطلقاً (تُستخدم حالات `cancelled` أو `void` مع ذكر السبب).

## 2. دورة حياة Outbox Worker
1. **Trigger**: يعمل تلقائياً عند توفر اتصال الإنترنت (Network Reachability + Exponential Backoff: `2s, 5s, 15s, 30s, 60s`) أو يدوياً من `Sync Center`.
2. **Push Phase**:
   - يقرأ الدفعات المعلقة (`status = 'pending' OR (status = 'failed' AND next_retry_at <= now)`).
   - يرسلها إلى Cloud Function `syncIngest` بترتيب زمني يحترم الاعتماديات (`patient -> appointment/visit -> consultation/lab_order/prescription -> invoice -> payment`).
   - تستجيب السحابة لكل عنصر بأحد الحالات: `applied`, `already_processed (idempotent)`, `conflict`, أو `rejected_auth_validation`.
3. **Pull Phase (Inbox)**:
   - يجلب التحديثات السحابية الأحدث من `sync_metadata['last_pull_cursor']`.
   - يطبق التغييرات غير المتعارضة على الجداول المحلية ويسجل `operationId` في `sync_inbox`.
   - يبث تحديثات الحالة إلى أجهزة LAN المتصلة عبر WebSocket.

## 3. قواعد حل التعارض حسب الكيان
| الكيان | السياسة عند التعارض (`remoteVersion > baseVersion`) |
|---|---|
| `consultations`, `lab_results`, `prescriptions` | **حفظ النسختين + إحالة إلزامية لمراجعة الطبيب/المدير** (`sync_conflicts`) |
| `invoices`, `payments`, `expenses`, `cashbox_shifts` | **حفظ النسختين + منع التكرار + مراجعة المحاسب/المدير** |
| `patients` (البيانات الديموغرافية/الحساسية) | **حفظ النسختين + مراجعة الاستقبال/الطبيب** (مع الحفاظ التراكمي على الحساسية والأمراض المزمنة) |
| `queue_tickets` (حالة الانتظار اليومية) | تحكم خادمي حسب آلة الحالة (`waiting -> called -> in_consultation -> completed`)؛ لا تعود الحالة للخلف بصمت |
| `settings`, `catalog` | يعتمد آخر تحديث إداري موثق مع تسجيل في `audit_logs` |

## 4. الاستعادة بعد انقطاع الكهرباء أو إغلاق التطبيق
- عند إقلاع `Local Clinic Server`، يفحص السجلات العالقة في حالة `in_flight` لأكثر من دقيقتين ويعيدها تلقائياً إلى `pending` دون فقدان أي عملية.
- تضمن مفاتيح `idempotencyKey` عدم تكرار أي عملية أُرسلت قبل انقطاع الكهرباء مباشرة.
