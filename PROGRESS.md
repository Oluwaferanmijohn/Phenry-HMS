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

---

## Bugfix round — 9 issues from the post-build audit (`00000000000013_bugfix_round.sql` + matching `.vue` changes)

- [x] **Doctor's Investigations & Scans page was read-only** — `cycle_investigations`/`cycle_ultrasounds` had RLS but no writer anywhere in the app. Added "Add Result" and "Log Scan" forms to `pages/doctor/investigations.vue`.
- [x] **`lab_results.values[].flag` was hardcoded `false`** — new `composables/useLabFlag.ts` parses the template's free-text reference range (`"3.5-12.5"`, `"< 5"`, `"≥ 40"`, etc.) and computes a real flag; wired into `LabResultsEntryPage.vue`'s save and the new investigations form. **Also found while fixing this**: Doctor had zero SELECT policy on `lab_results` at all — not a UI gap, an RLS gap, meaning Consultation's lab-results panel was silently empty for every Doctor regardless of the flag. Added the missing policy. `PatientDetailModal.vue`'s "Past Tests" now expands to show flagged values in red/bold with ⚠ — previously nothing rendered the field even when true.
- [x] **Postponed items were a dead end** — `TransferCryoSchedulePage.vue` now keeps Done/Postpone/Cancel available on a Postponed row (previously only a read-only Notes button); `LabWorklistPage.vue`'s active-worklist query now includes Postponed alongside Scheduled.
- [x] **Lab Results Entry form didn't clear on patient switch** — `loadPatient()` now resets `values`/`remarks`; the template-switch watcher now also clears `remarks` (previously only `values`).
- [x] **`cryo_tanks.used` only ever climbed** — added `status`/`used_date`/`used_by` to `cryo_records` + an atomic `use_cryo_record()` RPC (SECURITY DEFINER, same pattern as `approve_milestone`) that decrements the tank on partial or full use. "Use / Remove" action added to `pages/chief_embryologist/cryo.vue`.
- [x] **"Order Tests" on Consultation wrote nothing** — checkboxes are now bound to real state; "Send to Lab" inserts into a new `lab_test_orders` table (Doctor/Matron originate, Lab Tech/Chief Embryologist see + action, deliberately can't originate). `LabWorklistPage.vue` gets a "Pending Test Orders" queue so the loop actually closes.
- [x] **A cycle could never close or advance** — RLS already allowed it (Doctor: own patients, Matron: all); this was purely a missing-UI problem. Added stage-advance + "Close Cycle / Record Outcome" controls to `ConsultationPage.vue` (Doctor's only cycle touchpoint) and `CycleDetailModal.vue` (Matron's Macro Cycle View, gated behind a new `canManage` prop so Nurse's read-only view is unaffected). Success-rate KPIs, the eligible-patients dropdown, and every "stuck at Baseline" display all resolve themselves once cycles can actually reach `Closed` — no changes needed there.
- [x] **Private-bucket files had no read path** — no `createSignedUrl`/`getPublicUrl` call existed anywhere. Fixed `pages/patient/results.vue` (was `window.open`-ing a raw storage path, which 404s) and added a "View Proof" action to `pages/admin_manager/financial.vue`. **Also found while fixing this**: Lab Tech had *zero* storage policy on `lab-external-results` (only Chief Embryologist did) even though `pages/lab_tech/results.vue` reuses the same upload modal — every upload from that role was silently failing RLS. Added it, plus read policies for Patient (own folder), Doctor (own patients), and Matron (clinic-wide) — none of which existed before.
- [x] **Patient's claimed payment amount/date were collected and discarded** — added `claimed_amount`/`claimed_payment_date` to `payment_milestones` (the existing patient-update trigger is a blocklist, so no trigger change needed); `patient/payments.vue` now sends them; `admin_manager/financial.vue` now shows what the patient claims alongside the expected amount, highlighting a mismatch.

---

## Bugfix round 2 (`00000000000014_bugfix_round_2.sql` + matching `.vue` changes)

- [x] **Root cause of "cycle created but nothing shows on the cycle page"** — `MacroCycleView.vue`'s `load()` query tried to embed `bio_details` directly off `cycles` (`bio_details:patient_id(...)`) — there's no FK between the two tables (both independently reference `patient_names`), so PostgREST rejected the embed on *every* load, not just for new cycles. No cycle — old or new — was ever going to show on this page. Fixed by fetching `bio_details` separately and joining client-side (same pattern already used in `pages/patient/home.vue`).
- [x] **Cycle Manager** — `cycles.cycle_manager_id` (must reference a `role = 'nurse'` profile, enforced by trigger). Matron assigns one on the "Start New Cycle" form (`StartCycleModal.vue`, required field) and can reassign later from `CycleDetailModal.vue`. Displayed on the Macro Cycle View list, Consultation, and the patient's own Treatment Planner.
- [x] **Day-by-day protocol chart** — `cycle_daily_logs` gained `phase`/`medication`/`milestone` columns. New `composables/useIvfProtocol.ts` encodes the clinic's standard DR→Stimulation→OPU protocol (transcribed exactly from the reference chart) as a template; new `components/shared/CycleDayChart.vue` renders it as Date/Cycle Day/Medication/Sign-Notes with a "Generate Standard Protocol" action, and is wired in everywhere a cycle is shown: `CycleDetailModal.vue` (Nurse edits, matching nurse_role.sql's own "the one thing Nurse can write" policy), `ConsultationPage.vue` and `PatientDetailModal.vue` (read-only), `patient/treatment.vue` (read-only, replacing the old boolean-only tracker), and `lab_tech/patients.vue`. Deliberately stops at Egg Collection/OPU — Transfer/Beta-hCG/Viability timing is a real-time clinical call, not something to hardcode; the chart supports adding further days once decided.
- [x] **"Any of the qualified" staff couldn't view a patient's cycle file** — Chief Embryologist and Lab Tech had zero RLS access to `cycles`/`cycle_daily_logs`/`cycle_investigations`/`cycle_ultrasounds` (an intentional "matrix gives none" reading at the time). Both plan OPU/culture/cryo timing directly off cycle day, so granted read-only access on explicit product direction.
- [x] **Custom role permissions were a documented false claim** — `has_custom_permission()` existed but no RLS policy anywhere ever called it; the middleware comment asserted enforcement that didn't exist. Wired it for real (new `custom_role_scope_ok()` helper + view/create/edit policies) across all 10 resources `PermissionsBuilder.vue` manages, and corrected the comment. No visible behavior change today — custom-role users still land on `/no-access` since no screens exist for them yet — but the data layer's claim is now actually true, which is what matters for whoever builds those screens next.
- [x] **Every patient assigned to the same one doctor, forever** — `register_new_patient()` picked `order by created_at asc limit 1`, always the first doctor ever created. Switched to least-loaded assignment (fewest currently-assigned patients) across active doctors. Also fixed the same underlying assumption in `receptionist/book.vue`, which could only ever book against one arbitrarily-picked doctor — now a proper picker across all doctors.
- [x] **Two calendars stuck on the current month** — `receptionist/book.vue` and `StaffCalendarPage.vue` (Matron's shift roster) both computed year/month once from `new Date()` with no navigation. Added prev/next month controls to both, plus the past-date guard `patient/appointments.vue` already had but the receptionist version was missing (a receptionist could click any earlier day in the current month and book a date that's already passed).
- [x] **"Comprehensive audit log" gap** — partially closed. Staff account *creation* turned out to already be logged (via a direct `audit_log` insert in `server/api/admin/create-staff.post.ts` — the original audit only grepped `.sql` migrations and missed it). Revoking/reinstating access and changing a staff member's role were genuinely unlogged — both now call `log_audit_event()`. Full coverage of every sensitive mutation across all 10 roles is still open, same as noted above — this closed the two gaps explicitly called out, not the whole surface.

---

## Post-deploy fixes (found after 013/014 were actually run against a live Supabase instance)

- [x] **`create policy ... already exists` on re-run** — 013/014 were plain SQL pasted into the Supabase SQL editor, not CLI-tracked migrations, so re-running them (e.g. after fixing an unrelated error further down the file) hit "already exists" on the very first `create policy`. Every `create policy`/`create trigger` in both files now has a `drop ... if exists` immediately before it, and every `create table`/`create index`/`add column` uses `if not exists` — both files are now safe to run any number of times.
- [x] **Cycle Manager field could silently block cycle creation** — it was required on the "Start New Cycle" form; with zero Nurse accounts on staff, `nurses` comes back empty and the Start button stayed permanently disabled with no explanation. Made optional (`StartCycleModal.vue`) — also fixed a leftover stale guard in `submit()` that still required it internally after the template's `:disabled` no longer did.
- [x] **Cycle saved successfully but still didn't show in the list** — `cycle_manager_id` is a brand-new FK (from `00000000000014`), and PostgREST caches table-relationship metadata separately from plain column writes. A plain `INSERT` of the scalar value doesn't need that cache to be current; a `cycle_manager:cycle_manager_id(full_name)` **embed** does — so a not-yet-refreshed schema cache let the insert succeed while silently failing the embedded read, blanking out the *entire* cycle list rather than just the manager's name. Removed every embed depending on that FK (5 places — `MacroCycleView`, `CycleDetailModal`, `ConsultationPage`, `PatientDetailModal`, `PatientsSearchPage`) in favor of a plain follow-up query (new `composables/useCycleManagerNames.ts`), the same defensive pattern that fixed the original root-cause bug — the cycle list can no longer be taken down by a stale schema cache at all.
- [x] **Patient Detail view showed no surgery or transfer/cryo info** — never built, not a regression, but a real gap matching "show all about the patient." `PatientDetailModal.vue` now fetches and displays `surgery_schedule` and `transfer_cryo_schedule` for the patient directly (self-contained, same pattern as cycle manager resolution — works for every one of its 5+ callers without each needing its own query). Surfaced two RLS gaps in migration `00000000000015`: Admin had no read access to `surgery_schedule` at all, and Doctor/Matron/Nurse had no read access to `transfer_cryo_schedule` (only Chief Embryologist/Lab Tech/Admin could see it) — the clinical staff actually treating the patient couldn't see whether a transfer was even scheduled. Both fixed read-only; scheduling/actioning authority is unchanged.

---

## Bugfix round 5 (`00000000000016_bugfix_round_4.sql` + matching `.vue`/`.ts` changes)

- [x] **Emergency Override/Broadcast did nothing** — was a single `toast()` call asserting in the past tense that a broadcast had been sent; no message, no notification, no database record. Built the real thing: `profiles.phone` (didn't exist — staff weren't reachable at all), a `trigger_emergency_broadcast()` RPC (role-gated to Matron/Admin Manager) that logs the broadcast, resolves every active clinical-staff recipient, and asks `pg_net` to invoke a new `notify-emergency-broadcast` edge function that sends through the same Evolution API the patient-appointment notifier already uses — kept as its own function rather than extending `notify-whatsapp`, which is tightly scoped to `messages_log`'s two allowed trigger types per spec §4.3 and hardcoded to a single-patient lookup. Sidebar button now opens a real confirmation modal (`EmergencyBroadcastModal.vue`) and reports actual delivery counts, including staff with no phone on file who won't be reached. "On-call clinical staff" reads as every active Doctor/Matron/Nurse/Chief Embryologist/Lab Tech account — flagged as an interpretation call, since there's no dedicated on-call rota as a queryable schema concept to key off instead.
- [x] **Global search bar did nothing on every page** — `Topbar.vue`'s input had no binding at all. Wired to navigate to the current role's patients page with the query (`?q=`), which each patients-list page (`PatientsSearchPage.vue`, `receptionist/patients.vue`, `lab_tech/patients.vue`) now reads on mount to pre-fill its own already-working local filter — reuses existing, working search logic rather than building a second parallel implementation. Hidden entirely for Pharmacy/Stakeholder/Patient, which have no patients list to search (previously showed a decorative box promising a search that could never work for those roles).
- [x] **"Offline Sync Ready" showing while connected** — read as a status contradiction (first word a properly-connected user sees is "Offline"). Now just "Online"; the actual offline state ("Offline · N pending") was already worded fine and is unchanged.
- [x] **Revoking access didn't affect an already-open session** — `profile` is a session-cached singleton only re-fetched on login or a hard reload; nothing was listening for it changing mid-session, so a revoked account could keep using every page RLS still allowed until they signed out themselves. New `plugins/session-guard.client.ts` subscribes to Realtime on the user's own `profiles` row (migration enables Realtime on that table) plus a 60s polling fallback in case the channel silently drops — either one detecting `active === false` signs them out immediately, in place, no navigation required. Shares a new `forceSignOutRevoked()` helper with the middleware's existing route-change check (kept as two separate call sites, not one refactored path — `navigateTo()` needs to be returned directly from middleware for Nuxt's SSR redirect handling, which a shared async helper would risk breaking there; the client-only plugin has no such constraint).

---

## Bugfix round 6 — external audit follow-up + new feature requests

**Ground-truthed against the audit doc first**, since two of its items (session revocation, the lab-order alert popup) described a `realtime.client.ts`/`REALTIME_TABLES`/`refreshNuxtData()` system that doesn't exist anywhere in this codebase — confirmed by grep, not just recollection. Session revocation is already correctly handled by `session-guard.client.ts` above via a different, self-contained mechanism (direct Realtime subscription calling `loadProfile()`/`forceSignOutRevoked()`, no `refreshNuxtData()` dependency) that doesn't have the flaw the audit described. Didn't fabricate a fix for a file that isn't there.

- [x] **`recovery_beds` readable by Patient** — policy excluded only Stakeholder. Now excludes Patient too.
- [x] **Stale `queueOrRun` closures — full sweep, all 43 call sites** — every offline-queueable action across the app checked; confirmed and fixed in 20 (full list in commit), confirmed already-safe in the rest (closures over a captured object with a stable `.id`, not a drifting ref — no change needed). Two — `pharmacy/overview.vue`'s `restock()` and `pharmacy/inventory.vue`'s `logShipment()`, plus both nurse requisition forms — were worse than "stale": the form field gets cleared *immediately* after `queueOrRun` returns, but `queueOrRun` doesn't wait for the actual write when offline, so a queued action was **guaranteed** to replay reading `null`/reset values, corrupting inventory quantities to `NaN`. Not theoretical — confirmed by reading `useSyncQueue.ts`'s actual offline branch, which resolves before `run()` ever executes.
- [x] **"Recent Staff Changes" showed recently-hired** — rebuilt off `audit_log` (Created/Revoked/Reinstated/Changed Role entries, the ones bugfix round 5 added logging for) instead of `staff.slice(-3)`.
- [x] **`clinic_name` not editable** — added to Settings' Company Profile card and its save call.
- [x] **Doctor had no Surgery & Procedures page; Chief Embryologist and Lab Tech had zero visibility into it at all** — new pages for all three, reusing the existing shared `SurgeryPage.vue` (Doctor: full scheduling access, now widened to see every procedure clinic-wide rather than only their own — matches "assigned to him or not," with a "You" badge on their own cases; Embryologist/Lab Tech: read-only awareness, `canDocument=false` since operative reports stay a Doctor/Matron/Nurse responsibility). **Found while building this**: `ScheduleProcedureModal.vue`'s insert and two separate read queries (`SurgeryPage.vue`, `matron/overview.vue`) were all writing/embedding a column called `assigned_provider_id` — which has never existed; the real column is `assigned_doctor_id`. Every "Schedule Procedure" submission has been failing outright, and the Surgery page has been silently empty for Matron/Nurse this whole time. Predates this round entirely; fixed as a byproduct of wiring the new pages.
- [x] **No way to track embryos transferred vs. remaining in storage** — `transfer_cryo_schedule.embryos_used` captured when marking a Transfer event Done (shown against current cryo-storage count for context in the same modal); `PatientDetailModal.vue`'s Transfer & Cryopreservation section now shows both totals — embryos transferred (sum of completed Transfer events) and currently in storage (sum of `cryo_records` with `status = 'Stored'`) — as two directly-verifiable numbers rather than one derived "remaining" figure that would need assumptions about a total original count nothing actually tracks.
- [x] **Payment Plan Generator not reachable from Consultation** — it was already patient-scoped (a per-patient dropdown, contrary to how the request read); what was missing was a path *into* it without leaving the consult and re-picking from that dropdown. Added a link from Consultation (Doctor) that pre-selects the current patient via `?patient=`.
- [x] **Consultation's "Follicular Tracking Scan" / "Post-Op Note" tabs were decorative** — no click handler, no state, no corresponding content. Turned out `consultations.type` was already free-text and hardcoded to `'Standard Consult'` at save time — made the tabs real, switching both the note's placeholder and the saved `type`, rather than building two redundant new forms next to functionality that already existed for exactly this.
- [x] **Nursing vitals were entirely fake** — confirmed worse than "too basic": Triage & Vitals, Nursing Assessment, and Post-Visit Instructions had no `v-model`, no table, nothing — "Save & Proceed" only ever toasted (only Medication Admin, a separate step, actually wrote anywhere). New `nurse_visits` table (BP, temp, pulse, SpO₂, height, weight with an auto-computed BMI, condition, nursing notes, post-visit instructions), saved incrementally per step rather than only at the end so a nurse stepping away mid-visit doesn't lose what's already entered.
- [x] **Spouse/partner not a real linked record** — `bio_details.spouse_patient_id` (FK to `patient_names`), with a search-and-link picker on the nurse visit page. The existing `spouse` jsonb stays as freeform notes for when the partner isn't a registered patient.
- [x] **No signed consent form upload** — new private `consent-forms` storage bucket + `bio_details.consent_form_url`, upload/view control added to the nurse visit page (clinical roles + Reception can upload/view; a patient can view their own).
- [x] **Patients had no way to log into the portal at all** — confirmed, not an exaggeration: `register_new_patient()` never created an Auth account, and the login page was email/password only. Built: `handle_new_user()` extended to pick up `patient_id` from metadata; new `server/api/receptionist/create-patient-account.post.ts` (mirrors `create-staff.post.ts`'s service-role pattern) that provisions the account with a synthetic, non-deliverable email (`{patient_id}@patient.phenryhealth.internal` — Supabase Auth's password sign-in is inherently email-shaped, there's no arbitrary-username mode) and the patient's surname as the temporary password; `force_password_reset` reuses the exact gate already built for staff, no changes needed there. `pages/login.vue` gained a Staff/Patient toggle. Registration now calls the new endpoint immediately after `register_new_patient()` succeeds and shows the receptionist the login ID + temporary password to relay to the patient; if account creation fails, the patient is still successfully registered — the failure is surfaced clearly rather than silently dropped, since Admin can set the login up separately.

