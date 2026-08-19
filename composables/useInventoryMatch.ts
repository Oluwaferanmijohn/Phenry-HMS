// Prescriptions (medication) and requisition line items (items[].name) are
// both free text — neither carries a pharmacy_inventory FK or a guaranteed
// exact-string match. RxModal's own placeholder ("e.g. Ovidrel 250mcg") and
// the nurse requisition picker are both meant to reference an inventory
// item's name, but a straight `===` comparison (the original code in both
// dispense flows) silently fails on anything but a byte-perfect match —
// which is exactly how stock deduction was getting skipped with no error.
//
// This does the same name lookup, just tolerant of case/whitespace, and
// falls back to a "medication text starts with the inventory name" check so
// a typed value like "Gonal-F 450 IU, 2 pens" still resolves.
export function matchInventoryItem(inventory: any[], text: string | null | undefined) {
  const needle = String(text || '').trim().toLowerCase()
  if (!needle) return null
  const exact = inventory.find((i) => String(i.name).trim().toLowerCase() === needle)
  if (exact) return exact
  return inventory.find((i) => needle.startsWith(String(i.name).trim().toLowerCase())) || null
}
