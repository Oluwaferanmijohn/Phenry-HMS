export interface NavItem {
  id: string
  label: string
  icon: string
  section?: string
}
export interface RoleMeta {
  label: string
  subtitle: string
  icon: string
  nav: NavItem[]
}

// Ported verbatim from the prototype's js/app.js ROLE_META. This is shell
// configuration (labels/icons/routes), not page logic — safe to bring in
// whole even though only the `patient` role's pages exist so far. Each
// role's actual page components are still built one role at a time.
export const ROLE_META: Record<string, RoleMeta> = {
  patient: {
    label: 'Patient', subtitle: 'Companion App', icon: 'home',
    nav: [
      { id: 'home', label: 'Home', icon: 'home' },
      { id: 'medications', label: 'Medication Tracker', icon: 'pill' },
      { id: 'appointments', label: 'Book Appointment', icon: 'calendar' },
      { id: 'treatment', label: 'Treatment Planner', icon: 'layers' },
      { id: 'results', label: 'Results & Invoices', icon: 'file' },
      { id: 'payments', label: 'Payment Plan', icon: 'cash' },
    ],
  },
  receptionist: {
    label: 'Receptionist', subtitle: 'The Front Line', icon: 'users',
    nav: [
      { id: 'overview', label: 'Waiting Room', icon: 'users' },
      { id: 'book', label: 'Book Appointment', icon: 'calendar' },
      { id: 'schedule', label: 'Master Schedule', icon: 'calendar' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'register', label: 'New Registration', icon: 'clipboard' },
      { id: 'messages', label: 'Messages', icon: 'message' },
    ],
  },
  admin_manager: {
    label: 'Admin Manager', subtitle: 'The Powerhouse', icon: 'briefcase',
    nav: [
      { id: 'overview', label: 'Overview', icon: 'grid' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'staff', label: 'Staff Management', icon: 'users' },
      { id: 'financial', label: 'Financial Approvals', icon: 'cash' },
      { id: 'settings', label: 'Global Settings', icon: 'settings' },
      { id: 'audit', label: 'Security & Audit Log', icon: 'shield' },
      { id: 'exec_overview', label: 'Executive Overview', icon: 'grid', section: 'Executive View' },
      { id: 'exec_financials', label: 'Financials', icon: 'cash', section: 'Executive View' },
      { id: 'exec_operations', label: 'Clinical Operations', icon: 'activity', section: 'Executive View' },
      { id: 'exec_growth', label: 'Growth & Acquisition', icon: 'target', section: 'Executive View' },
    ],
  },
  doctor: {
    label: 'Doctor', subtitle: 'The Clinical Hub', icon: 'flask',
    nav: [
      { id: 'waiting', label: 'Global Waiting Room', icon: 'users' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'consultation', label: 'Consultation', icon: 'clipboard' },
      { id: 'appointments', label: 'Appointments', icon: 'calendar' },
      { id: 'investigations', label: 'Investigations & Scans', icon: 'flask' },
      { id: 'billing', label: 'Payment Plan Generator', icon: 'cash' },
      { id: 'exec_overview', label: 'Executive Overview', icon: 'grid', section: 'Executive View' },
      { id: 'exec_financials', label: 'Financials', icon: 'cash', section: 'Executive View' },
      { id: 'exec_operations', label: 'Clinical Operations', icon: 'activity', section: 'Executive View' },
      { id: 'exec_growth', label: 'Growth & Acquisition', icon: 'target', section: 'Executive View' },
    ],
  },
  matron: {
    label: 'Matron', subtitle: 'The Floor Commander', icon: 'award',
    nav: [
      { id: 'overview', label: 'Clinical Hub', icon: 'grid' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'consultation', label: 'Consultation', icon: 'clipboard' },
      { id: 'cycles', label: 'Macro Cycle View', icon: 'layers' },
      { id: 'surgery', label: 'Surgery & Procedures', icon: 'siren' },
      { id: 'staffing', label: 'Staff Allocation & Shifts', icon: 'users' },
      { id: 'beds', label: 'Recovery Beds', icon: 'bed' },
      { id: 'billing', label: 'Payment Plans', icon: 'cash' },
    ],
  },
  nurse: {
    label: 'Nurse', subtitle: 'The Execution Layer', icon: 'activity',
    nav: [
      { id: 'overview', label: 'Clinical Dashboard', icon: 'grid' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'cycles', label: 'Macro Cycle View', icon: 'layers' },
      { id: 'visit', label: 'Visit Documentation', icon: 'clipboard' },
      { id: 'surgery', label: 'Surgery & Procedures', icon: 'siren' },
      { id: 'requisitions', label: 'Inventory Requisition', icon: 'box' },
      { id: 'beds', label: 'Recovery Beds', icon: 'bed' },
      { id: 'billing', label: 'Payment Plans', icon: 'cash' },
      { id: 'staffing', label: 'My Shift', icon: 'clock' },
    ],
  },
  chief_embryologist: {
    label: 'Chief Embryologist', subtitle: 'The Lab Director', icon: 'snow',
    nav: [
      { id: 'overview', label: 'Lab Pipeline Oversight', icon: 'grid' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'worklist', label: 'Active Worklist', icon: 'clipboard' },
      { id: 'results', label: 'Enter Lab Results', icon: 'flask' },
      { id: 'embryo', label: 'Embryo Grading', icon: 'layers' },
      { id: 'schedule', label: 'Transfer & Cryo Schedule', icon: 'calendar' },
      { id: 'cryo', label: 'Cryo Management', icon: 'snow' },
      { id: 'qc', label: 'Equipment, QC & Supplies', icon: 'thermo' },
      { id: 'templates', label: 'Result Templates', icon: 'clipboard' },
      { id: 'staffing', label: 'Lab Staffing', icon: 'users' },
    ],
  },
  lab_tech: {
    label: 'Lab Technician', subtitle: 'The Data Entry Engine', icon: 'flask',
    nav: [
      { id: 'worklist', label: 'Active Worklist', icon: 'grid' },
      { id: 'patients', label: 'Patients', icon: 'user' },
      { id: 'results', label: 'Enter Lab Results', icon: 'flask' },
      { id: 'embryo', label: 'Embryo Grading', icon: 'layers' },
      { id: 'schedule', label: 'Transfer & Cryo Schedule', icon: 'calendar' },
      { id: 'templates', label: 'Reusable Templates', icon: 'clipboard' },
    ],
  },
  pharmacy: {
    label: 'Pharmacy & Inventory', subtitle: 'The Vault', icon: 'box',
    nav: [
      { id: 'overview', label: 'Dashboard', icon: 'grid' },
      { id: 'dispensations', label: 'Dispensations', icon: 'pill' },
      { id: 'requisitions', label: 'Ward Requisitions', icon: 'box' },
      { id: 'inventory', label: 'Inventory Ledger', icon: 'layers' },
    ],
  },
  stakeholder: {
    label: 'Stakeholder', subtitle: 'The KPI View', icon: 'target',
    nav: [
      { id: 'overview', label: 'Executive Overview', icon: 'grid' },
      { id: 'financials', label: 'Financials', icon: 'cash' },
      { id: 'operations', label: 'Clinical Operations', icon: 'activity' },
      { id: 'growth', label: 'Growth & Acquisition', icon: 'target' },
    ],
  },
}

export const ROLE_ORDER = [
  'patient', 'receptionist', 'admin_manager', 'doctor', 'matron', 'nurse',
  'chief_embryologist', 'lab_tech', 'pharmacy', 'stakeholder',
]

// Route prefix each role's pages live under — /patient/home, /doctor/waiting, etc.
// Falls back to /no-access (not /login!) for anything without a ROLE_META
// entry — that includes custom roles, which have no built UI yet (see
// middleware/auth.global.ts). Falling back to /login here would loop:
// the caller is already authenticated, so /login just bounces them forward
// through this same function again.
export function roleHomePath(role: string) {
  const meta = ROLE_META[role]
  return meta ? `/${role}/${meta.nav[0].id}` : '/no-access'
}
