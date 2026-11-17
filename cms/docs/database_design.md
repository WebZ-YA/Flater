# Clinic Management System (CMS) — Database Design (Firestore & Drift SQLite)

## 1. معايير البيانات المشتركة (Common Record Envelope)
جميع السجلات الأساسية في Firestore وSQLite تلتزم بالحقول التالية:
- `id`: `String (UUID v4)` — المعرف الثابت للسجل.
- `tenantId`: `String (UUID)` — معرف العيادة/المستأجر.
- `clinicId`: `String (UUID)` — معرف المنشأة الطبية.
- `branchId`: `String (UUID)` — معرف الفرع (افتراضياً `main-branch`).
- `createdAt`: `Timestamp / ISO-8601 UTC`
- `updatedAt`: `Timestamp / ISO-8601 UTC`
- `createdBy`: `String (uid)`
- `updatedBy`: `String (uid)`
- `schemaVersion`: `int` (حالياً `1`)
- `recordVersion`: `int` (يبدأ من `1` ويزداد مع كل تعديل لمراقبة التعارض Optimistic Concurrency)
- `syncStatus`: `String` (`synced | pending_push | conflict | local_only`)
- `deletedAt`: `Timestamp?` (Tombstone للحذف المنطقي الآمن فقط في الكيانات المسموح بأرشفتها؛ السجلات الطبية والمالية والتدقيقية لا تُحذف فعلياً).

---

## 2. Cloud Firestore Collections & Subcollections

```text
/platform
  /administrators/{adminUid}
  /configuration/{configId}

/tenants/{tenantId}                        (Tenant root doc: name, plan, defaultCurrency: "YER", status)
  /settings/{settingId}                    (clinic profile, working hours, appointment duration, labFeeSeparation: true)
  /branches/{branchId}                     (name, address, phone, active)
  /memberships/{userId}                    (role, customPermissions[], branchIds[], active, email)
  /patients/{patientId}                    (medicalNumber: "PAT-000001", fullName, normalizedPhone, gender, dob, bloodType, allergies[], chronicConditions[], archived)
  /appointments/{appointmentId}            (patientId, doctorId, branchId, startAt, endAt, visitType, status, notes)
  /queue_tickets/{ticketId}                (queueDate: "YYYY-MM-DD", ticketNumber, patientId, doctorId, appointmentId?, visitType, priority, status, calledAt, completedAt)
  /visits/{visitId}                        (visitNumber: "VIS-000001", patientId, doctorId, appointmentId?, queueTicketId?, visitType, status: "in_progress|finalized|cancelled", finalizedAt)
  /consultations/{consultationId}          (visitId, patientId, doctorId, chiefComplaint, symptoms, medicalHistory, vitals{}, physicalExam, diagnoses[], clinicalNotes, treatmentPlan, isDraft, approvedAt)
  /laboratories/{labId}                    (name, contactName, phone, email, address, integrationMode: "manual|portal|api", active)
  /medical_tests/{testId}                  (code, nameAr, nameEn, category, referenceRange, unit, defaultLabId?, labPrice, clinicFee)
  /lab_orders/{orderId}                    (orderNumber: "LAB-000001", patientId, visitId, doctorId, laboratoryId, status: "issued|sent|sample_collected|partial_results|completed|cancelled", qrPayload)
    /items/{itemId}                        (testId, testCode, testNameAr, testNameEn, status)
  /lab_results/{resultId}                  (orderId, patientId, visitId, laboratoryId, source: "manual|portal|api", receivedAt, receivedBy, fileUrl?, originalFileName?, structuredValues[], reviewStatus: "pending_review|approved|rejected", reviewedBy?, reviewedAt?, doctorNotes)
  /medications/{medId}                     (tradeName, scientificName, concentration, dosageForm, defaultInstructions)
  /prescriptions/{prescriptionId}          (rxNumber: "RX-000001", patientId, visitId, doctorId, status: "active|modified|cancelled", revisionOf?, cancelReason?)
    /items/{itemId}                        (medicationId?, tradeName, scientificName, concentration, dosageForm, dose, frequency, duration, route, instructions, warnings)
  /documents/{documentId}                  (patientId, visitId?, labOrderId?, category, title, storagePath, mimeType, sizeBytes, version, checksumSha256, archived)
  /invoices/{invoiceId}                    (invoiceNumber: "INV-000001", patientId, visitId?, status: "draft|issued|partially_paid|paid|void", subtotalClinic, externalLabPassThrough, discountAmount, discountAuthorizedBy?, totalDue, paidAmount, remainingAmount, currency: "YER")
    /items/{itemId}                        (serviceType: "consultation|follow_up|procedure|external_lab_passthrough", description, unitPrice, quantity, total, isExternalLabFee)
  /payments/{paymentId}                    (invoiceId, patientId, shiftId, paymentReference (unique), amount, currency: "YER", method: "cash|card|transfer", type: "payment|refund", receiptNumber, collectedBy)
  /expenses/{expenseId}                    (shiftId?, category, description, amount, currency: "YER", vendor, receiptRef, recordedBy, approvedBy?)
  /cashbox_shifts/{shiftId}                (cashierId, branchId, openedAt, closedAt?, openingBalance, totalCashIn, totalCashOut, expectedClosingBalance, actualCountedBalance?, variance?, status: "open|closed")
  /notifications/{notificationId}          (targetUserId, type, title, body, entityType, entityId, isRead)
  /audit_logs/{logId}                      (actorId, actorRole, action, entityType, entityId, sourceDevice, occurredAt, beforeSummary?, afterSummary?)
  /sync_conflicts/{conflictId}             (entityType, entityId, localVersion, remoteVersion, localSnapshot, remoteSnapshot, status: "pending_review|resolved_local|resolved_remote|merged", resolvedBy?, resolvedAt?)
  /integrations/{integrationId}            (providerType, laboratoryId?, status, webhookEndpoint, lastHealthCheckAt)
  /laboratory_events/{eventId}             (idempotencyKey, laboratoryId, orderId?, eventType, status, receivedAt)
```

---

## 3. Composite Indexes (الفهارس المركبة الأساسية)

مُعرّفة في `cms/firebase/firestore.indexes.json`:
1. `patients`: `(archived ASC, fullName ASC)`, `(normalizedPhone ASC, archived ASC)`, `(medicalNumber ASC)`
2. `appointments`: `(doctorId ASC, startAt ASC)`, `(branchId ASC, status ASC, startAt ASC)`
3. `queue_tickets`: `(queueDate ASC, status ASC, ticketNumber ASC)`, `(doctorId ASC, queueDate ASC, status ASC)`
4. `visits`: `(patientId ASC, createdAt DESC)`, `(doctorId ASC, status ASC, createdAt DESC)`
5. `lab_orders`: `(patientId ASC, createdAt DESC)`, `(laboratoryId ASC, status ASC, createdAt DESC)`
6. `lab_results`: `(reviewStatus ASC, receivedAt DESC)`, `(orderId ASC, receivedAt DESC)`
7. `invoices`: `(patientId ASC, createdAt DESC)`, `(status ASC, createdAt DESC)`
8. `payments`: `(shiftId ASC, createdAt DESC)`, `(paymentReference ASC)`
9. `audit_logs`: `(entityType ASC, entityId ASC, occurredAt DESC)`, `(actorId ASC, occurredAt DESC)`

---

## 4. Local Database (SQLite + Drift ORM)

تُطابق الجداول المحلية الـ 15+ نموذج Firestore مع إضافة فهارس SQLite المحلية (`UNIQUE INDEX` على `medical_number`, `payment_reference`, `idempotency_key`, `queue_date + ticket_number`) لضمان منع التكرار حتى أثناء العمل بدون إنترنت.

### جداول المزامنة الأساسية:
- `sync_outbox`: `id`, `tenant_id`, `entity_type`, `entity_id`, `operation`, `idempotency_key (UNIQUE)`, `base_version`, `payload_json`, `status`, `retry_count`, `last_error`, `created_at`, `next_retry_at`.
- `sync_inbox`: `id`, `tenant_id`, `operation_id (UNIQUE)`, `entity_type`, `entity_id`, `remote_version`, `payload_json`, `applied_at`.
- `sync_conflicts`: `id`, `tenant_id`, `entity_type`, `entity_id`, `local_version`, `remote_version`, `local_json`, `remote_json`, `status`, `resolution_note`, `resolved_by`, `created_at`, `resolved_at`.
- `sync_metadata`: `key (PK)`, `value` (مثل `last_pull_timestamp`, `device_id`, `schema_version`).

### سياسة الترحيل (Migrations):
- يبدأ المخطط بـ `schemaVersion = 1`.
- أي تعديل مستقبلي يتطلب `MigrationStrategy(onUpgrade: ...)` موثقة واختبارات ترحيل آلية دون حذف بيانات المرضى.
