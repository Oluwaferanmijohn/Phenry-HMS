export type LabTemplateVariable = { name: string; unit: string; ref: string }

export type LabStarterTemplate = {
  id: string
  name: string
  category: string
  description: string
  variables: LabTemplateVariable[]
}

// Stable IDs let the database migration and the UI recovery path safely share
// the same records without overwriting any template a laboratory has edited.
export const STARTER_LAB_TEMPLATES: LabStarterTemplate[] = [
  {
    id: '6a8cb770-5697-4b71-9d67-000000000001',
    name: 'SFA (Semen Fluid Analysis)',
    category: 'Andrology',
    description: 'Routine semen examination structure. Configure locally validated reference intervals before clinical use.',
    variables: [
      ['Abstinence period', 'days'], ['Liquefaction time', 'minutes'], ['Appearance', ''], ['Viscosity', ''],
      ['Semen volume', 'mL'], ['pH', ''], ['Sperm concentration', 'million/mL'], ['Total sperm number', 'million/ejaculate'],
      ['Progressive motility', '%'], ['Non-progressive motility', '%'], ['Immotile sperm', '%'], ['Vitality', '% live'],
      ['Normal morphology', '%'], ['Leukocytes', 'million/mL'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000002',
    name: 'Sperm Preparation / Post-Wash Analysis',
    category: 'Andrology',
    description: 'Pre- and post-preparation measurements for IUI, IVF, or ICSI workflows.',
    variables: [
      ['Preparation method', ''], ['Pre-wash volume', 'mL'], ['Pre-wash concentration', 'million/mL'],
      ['Pre-wash progressive motility', '%'], ['Post-wash volume', 'mL'], ['Post-wash concentration', 'million/mL'],
      ['Post-wash progressive motility', '%'], ['Total motile sperm count', 'million'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000003',
    name: 'Hormonal Panel (FSH, LH, E2)',
    category: 'Reproductive Endocrinology',
    description: 'Fertility hormone panel with cycle-day context and laboratory-specific reference intervals.',
    variables: [
      ['Cycle day', 'day'], ['FSH', 'IU/L'], ['LH', 'IU/L'], ['Estradiol (E2)', 'pg/mL'],
      ['Progesterone', 'ng/mL'], ['Prolactin', 'ng/mL'], ['TSH', 'mIU/L'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000004',
    name: 'IVF Cycle Monitoring Panel',
    category: 'IVF',
    description: 'Serial endocrine monitoring structure for an active ovarian-stimulation cycle.',
    variables: [
      ['Stimulation day', 'day'], ['Estradiol (E2)', 'pg/mL'], ['LH', 'IU/L'], ['Progesterone', 'ng/mL'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000005',
    name: 'Ovarian Reserve Screening',
    category: 'Reproductive Endocrinology',
    description: 'Biochemical ovarian-reserve structure for interpretation with age, cycle timing, and ultrasound findings.',
    variables: [
      ['Cycle day', 'day'], ['Anti-Müllerian hormone (AMH)', 'ng/mL'], ['Basal FSH', 'IU/L'], ['Basal estradiol (E2)', 'pg/mL'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000006',
    name: 'Pregnancy Test (Quantitative β-hCG)',
    category: 'Pregnancy',
    description: 'Quantitative serum beta-hCG reporting structure for serial clinical interpretation.',
    variables: [{ name: 'Beta-hCG', unit: 'mIU/mL', ref: '' }],
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000007',
    name: 'Pre-IVF Infectious Disease Screening',
    category: 'Serology',
    description: 'Pre-treatment infectious disease screening record using the laboratory assay wording.',
    variables: [
      ['HIV-1/2 antigen/antibody', 'Reactive / Non-reactive'], ['Hepatitis B surface antigen (HBsAg)', 'Reactive / Non-reactive'],
      ['Hepatitis C antibody', 'Reactive / Non-reactive'], ['Syphilis screen (RPR/VDRL)', 'Reactive / Non-reactive'], ['Rubella IgG', 'IU/mL'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
  {
    id: '6a8cb770-5697-4b71-9d67-000000000008',
    name: 'Blood Group & Full Blood Count',
    category: 'Haematology',
    description: 'Baseline blood-group and full-blood-count reporting structure.',
    variables: [
      ['ABO blood group', ''], ['Rhesus (RhD) type', 'Positive / Negative'], ['Haemoglobin', 'g/dL'],
      ['Packed cell volume', '%'], ['White blood cell count', '×10⁹/L'], ['Platelet count', '×10⁹/L'],
    ].map(([name = '', unit = '']) => ({ name, unit, ref: '' })),
  },
]

export const STARTER_LAB_TEMPLATE_IDS = new Set(STARTER_LAB_TEMPLATES.map((template) => template.id))
