# Phenry Health — Build Progress

Seeded from spec §3.11. Build order: `patient → receptionist → admin_manager →
doctor → matron → nurse → chief_embryologist → lab_tech → pharmacy → stakeholder`.

Note: spec §3.11's header says "Total: 61 pages/screens" but its own per-role
bullets sum to 73 (shared components like Patients/Consultation/Executive View
are listed once per role that uses them). Tracking all 73 nav entries here —
see the flagged discrepancy in chat if "61" should govern instead.

- [x] **Patient — 6 pages** (`pages/patient/*.vue`)
  - [x] Home — `pages/patient/home.vue`
  - [x] Medication Tracker — `pages/patient/medications.vue`
  - [x] Book Appointment — `pages/patient/appointments.vue`
  - [x] Treatment Planner — `pages/patient/treatment.vue`
  - [x] Results & Invoices — `pages/patient/results.vue`
  - [x] Payment Plan — `pages/patient/payments.vue`
  - [x] (gate) Forced password reset — `pages/reset-password.vue`

- [x] **Receptionist — 6 pages** (`pages/receptionist/*.vue`)
  - [x] Waiting Room — `pages/receptionist/overview.vue`
  - [x] Book Appointment — `pages/receptionist/book.vue`
  - [x] Master Schedule — `pages/receptionist/schedule.vue`
  - [x] Patients — `pages/receptionist/patients.vue`
  - [x] New Registration — `pages/receptionist/register.vue`
  - [x] Messages — `pages/receptionist/messages.vue`

- [x] **Admin Manager — 10 pages**
  - [x] Overview — `pages/admin_manager/overview.vue`
  - [x] Patients — `pages/admin_manager/patients.vue` (shared component)
  - [x] Staff Management (incl. custom-role permissions builder, §2.4) — `pages/admin_manager/staff.vue`
  - [x] Financial Approvals — `pages/admin_manager/financial.vue`
  - [x] Global Settings — `pages/admin_manager/settings.vue`
  - [x] Security & Audit Log — `pages/admin_manager/audit.vue`
  - [x] Executive Overview — `pages/admin_manager/exec_overview.vue` (shared component)
  - [x] Executive Financials — `pages/admin_manager/exec_financials.vue` (shared component)
  - [x] Executive Clinical Operations — `pages/admin_manager/exec_operations.vue` (shared component)
  - [x] Executive Growth & Acquisition — `pages/admin_manager/exec_growth.vue` (shared component)

- [x] **Doctor — 10 pages**
  - [x] Global Waiting Room — `pages/doctor/waiting.vue`
  - [x] Patients — `pages/doctor/patients.vue` (shared component)
  - [x] Consultation — `pages/doctor/consultation.vue` (shared component, built this round)
  - [x] Appointments — `pages/doctor/appointments.vue` (read-only per RLS — flagged)
  - [x] Investigations & Scans — `pages/doctor/investigations.vue`
  - [x] Payment Plan Generator — `pages/doctor/billing.vue`
  - [x] Executive Overview — `pages/doctor/exec_overview.vue` (shared component)
  - [x] Executive Financials — `pages/doctor/exec_financials.vue` (shared component)
  - [x] Executive Clinical Operations — `pages/doctor/exec_operations.vue` (shared component)
  - [x] Executive Growth & Acquisition — `pages/doctor/exec_growth.vue` (shared component)

- [x] **Matron — 8 pages**
  - [x] Clinical Hub — `pages/matron/overview.vue`
  - [x] Patients — `pages/matron/patients.vue` (shared component)
  - [x] Consultation — `pages/matron/consultation.vue` (shared component)
  - [x] Macro Cycle View (+ Start New Cycle) — `pages/matron/cycles.vue` (shared component, built this round)
  - [x] Surgery & Procedures (+ Pre-/Op/Post-Op reports) — `pages/matron/surgery.vue` (shared component, built this round)
  - [x] Staff Allocation & Shifts (editable) — `pages/matron/staffing.vue` (shared component, built this round)
  - [x] Recovery Beds — `pages/matron/beds.vue` (shared component, built this round)
  - [x] Billing Readiness — `pages/matron/billing.vue` (shared component, built this round)

- [x] **Nurse — 9 pages**
  - [x] Clinical Dashboard — `pages/nurse/overview.vue`
  - [x] Patients (view-only) — `pages/nurse/patients.vue` (shared component)
  - [x] Macro Cycle View — `pages/nurse/cycles.vue` (shared component; allow-create=false — see flagged spec conflict)
  - [x] Visit Documentation (incl. prescribing, §0.1) — `pages/nurse/visit.vue`
  - [x] Surgery & Procedures — `pages/nurse/surgery.vue` (shared component)
  - [x] Inventory Requisition — `pages/nurse/requisitions.vue`
  - [x] Recovery Beds — `pages/nurse/beds.vue` (shared component)
  - [x] Payment Plans — `pages/nurse/billing.vue` (shared component)
  - [x] My Shift (read-only) — `pages/nurse/staffing.vue` (shared component, editable=false)

- [x] **Chief Embryologist — 10 pages**
  - [x] Lab Pipeline Oversight — `pages/chief_embryologist/overview.vue`
  - [x] Patients — `pages/chief_embryologist/patients.vue` (shared component, full read-only context)
  - [x] Active Worklist — `pages/chief_embryologist/worklist.vue` (shared component; re-derived from transfer_cryo_schedule — no embryo_worklist table in spec, flagged)
  - [x] Enter Lab Results — `pages/chief_embryologist/results.vue` (shared component)
  - [x] Embryo Grading — `pages/chief_embryologist/embryo.vue` (shared component; no image capture, per spec)
  - [x] Transfer & Cryo Schedule — `pages/chief_embryologist/schedule.vue` (shared component)
  - [x] Cryo Management (tanks) — `pages/chief_embryologist/cryo.vue`
  - [x] Equipment, QC & Supplies — `pages/chief_embryologist/qc.vue`
  - [x] Result Templates — `pages/chief_embryologist/templates.vue` (shared component)
  - [x] Lab Staffing — `pages/chief_embryologist/staffing.vue`

- [x] **Lab Technician — 6 pages**
  - [x] Active Worklist — `pages/lab_tech/worklist.vue` (shared component)
  - [x] Patients — `pages/lab_tech/patients.vue` (dedicated — lab-relevant fields only via RPC, not the shared full-context component)
  - [x] Enter Lab Results (+ external upload) — `pages/lab_tech/results.vue` (shared component)
  - [x] Embryo Grading — `pages/lab_tech/embryo.vue` (shared component)
  - [x] Transfer & Cryo Schedule — `pages/lab_tech/schedule.vue` (shared component)
  - [x] Reusable Templates — `pages/lab_tech/templates.vue` (shared component)

- [x] **Pharmacy & Inventory — 4 pages**
  - [x] Dashboard — `pages/pharmacy/overview.vue`
  - [x] Dispensations — `pages/pharmacy/dispensations.vue` (shared component)
  - [x] Ward Requisitions — `pages/pharmacy/requisitions.vue` (same shared component — matches the prototype's `phRequisitions() { return phDispensations(); }` exactly)
  - [x] Inventory Ledger — `pages/pharmacy/inventory.vue`

- [x] **Stakeholder — 4 pages**
  - [x] Executive Overview — `pages/stakeholder/overview.vue` (shared component)
  - [x] Financials — `pages/stakeholder/financials.vue` (shared component)
  - [x] Clinical Operations — `pages/stakeholder/operations.vue` (shared component)
  - [x] Growth & Acquisition — `pages/stakeholder/growth.vue` (shared component)

---

## ✅ All 10 roles complete — 73/73 nav entries, verified by script against `useRoleMeta.ts`


---

## Infrastructure (not part of the 73-page count, built once)

- [x] Nuxt 3 + Tailwind + Supabase scaffold
- [x] Design system ported verbatim (`assets/css/main.css`, `tailwind.config.ts`)
- [x] Icon set, Badge/StatusBadge/EmptyState/Avatar/ProgressBar/StatCard/Modal/ToastStack components
- [x] Sidebar/Topbar/SyncPill shell (`layouts/default.vue`)
- [x] Auth: real login (`pages/login.vue`), forced-password-reset gate, `no-access` fallback
- [x] Role-aware global middleware (`middleware/auth.global.ts`)
- [x] Custom JWT claim mechanism (`app_role`/`custom_role_key` via Auth Hook) + deny-by-default custom-role RLS helpers
- [x] Offline write-queue composable (`useSyncQueue`) wired to real `navigator.onLine`
- [ ] PowerSync client wiring (deferred until all tables exist — see chat)
- [x] Appointment engine slot-computation RPC (`available_appointment_slots`)
- [x] MRN generator (`generate_mrn`, §4.1) + atomic `register_new_patient` RPC
- [x] Column-level access enforcement pattern (SECURITY DEFINER RPCs) for roles with partial table access — first used for Receptionist's "demographic fields only" scope
- [x] Shared clinical Patients search + detail modal (`components/shared/PatientsSearchPage.vue` + `PatientDetailModal.vue`) — built once during Admin, will just need thin wrapper pages for Doctor/Matron/Nurse/Chief Embryologist/Lab Tech
- [x] Shared Executive View (`components/shared/Exec*.vue` + 4 `exec_*` RPCs) — built once during Admin per §0.3, Doctor/Stakeholder just need wrapper pages
- [x] Real staff provisioning (`server/api/admin/create-staff.post.ts`) — temp password + forced reset on first login, same gate as Patient
- [x] Audit log (`audit_log` + `log_audit_event()`) — logs registration, financial approvals/rejections, staff creation so far; not yet instrumented on every table in the system (see chat)
- [ ] Custom-role UI: the permissions **data model** is fully built and enforced (create role → configure per-table view/create/edit/scope → deny-by-default), but there are no actual **screens** for a custom-role login to land on — neither the prototype nor the spec defines what those would look like. A custom-role user now correctly authenticates and is correctly recognized, but hits an honest "no screens built for this role yet" page. Flagged in chat, not silently built around.
- [x] Shared Consultation workflow (`components/shared/ConsultationPage.vue` + `RxModal.vue` + `ScheduleProcedureModal.vue`) — built once during Doctor, Matron just needs a thin wrapper page
- [x] `surgery_schedule` (minimal — Matron/Nurse extend with the full pre-op/op-notes/post-op workflow on the same `report` jsonb column)
- [x] Schema correction: `surgery_schedule.assigned_provider_id` (renamed from `assigned_doctor_id`) + separate `operative_reports` table, matching spec §1 exactly instead of the prototype's in-memory shape
- [x] Shared Macro Cycle View, Surgery page, Recovery Beds, Billing Readiness, Staff Calendar (`components/shared/*`) — built once during Matron, Nurse next round is mostly thin wrappers
- [x] `duty_roster` (§1 schema: text[] staff names, not normalized FKs — matched literally)
- [x] `requisitions` (§1 schema, new table — Nurse creates, Matron oversees, Pharmacy will approve/dispatch next)
- [x] Lab tables per spec §1 exact schema: `embryo_batches`, `transfer_cryo_schedule`, `cryo_tanks`, `cryo_records` (real `tank_id` FK, not the prototype's string match), `incubator_logs`, `lab_equipment`, `lab_store`
- [x] Shared lab pages (`components/shared/LabWorklistPage.vue`, `LabResultsEntryPage.vue`, `EmbryoGradingPage.vue`, `TransferCryoSchedulePage.vue`, `LabTemplateManager.vue`, `ExternalUploadModal.vue`) — built once during Chief Embryologist, Lab Tech next round is mostly thin wrappers
- [x] Spouse/Partner (SFA) section added to shared `PatientDetailModal.vue` — was missing, required by §3.8
- [x] Lab Tech column-restricted patient access (`patients_lab_directory`/`patient_lab_profile` RPCs) — same enforcement pattern as Receptionist
- [x] Trigger-based column locking for Lab Tech's "no tank admin" / "QC entry only" restrictions on `cryo_tanks`/`incubator_logs` (a self-referential `WITH CHECK` was drafted first and correctly caught as unreliable before shipping)
- [x] `pharmacy_inventory` (§1 schema, new table, deliberately separate from `lab_store` per spec's explicit note) + trigger-based "dispense/approve-only" restrictions on `prescriptions`/`requisitions` writes
- [x] WhatsApp trigger #1/#2 plumbing (`messages_log`, Postgres trigger, `notify-whatsapp` Edge Function)
- [x] Security audit before closing out: two pre-existing blanket `using (true)` policies (`clinic_settings`, `recovery_beds`) would have let Stakeholder bypass the "architecturally impossible" isolation bar via direct API calls even with no UI exposing it — tightened to exclude Stakeholder explicitly. Every other blanket policy in the schema (`custom_roles`, `lab_templates`) audited and confirmed to carry no patient-identifying data.
- [ ] Capacitor scaffold (deferred — see chat, doing this once real pages exist to wrap)
- [ ] Mobile Read-Only Search Mode (§4.6 — explicit ticket, not yet built)
- [ ] PowerSync client wiring (deferred until all tables exist — they now do; this is the next real piece of cross-cutting work)
- [ ] Custom-role UI screens (data model is done; see the note above — a real product decision, not a build gap)
- [ ] Audit log is not yet instrumented on every sensitive mutation across all 10 roles (currently: registration, financial approvals, staff creation) — extending coverage is mechanical from here, just needs deciding how much is wanted
