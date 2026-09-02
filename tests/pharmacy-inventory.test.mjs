import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { test } from 'node:test'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('pharmacy can manually create a new inventory item', async () => {
  const inventory = await read('pages/pharmacy/inventory.vue')

  assert.match(inventory, /Add New Drug/)
  assert.match(inventory, /Scan Drug · Coming Soon/)
  assert.match(inventory, /table: 'pharmacy_inventory', kind: 'insert'/)
  assert.match(inventory, /current_qty: currentQty/)
  assert.match(inventory, /batch_number: newDrug\.batch/)
  assert.match(inventory, /already in inventory; use Log New Shipment/)
})

test('pharmacy dashboard links directly to new-drug entry', async () => {
  const overview = await read('pages/pharmacy/overview.vue')
  assert.match(overview, /to="\/pharmacy\/inventory\?new=1"/)
})
