import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { test } from 'node:test'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('profile fetch failures are distinct from confirmed revocation', async () => {
  const auth = await read('composables/useAuth.ts')
  const guard = await read('plugins/session-guard.client.ts')
  const middleware = await read('middleware/auth.global.ts')

  assert.match(auth, /ProfileRefreshStatus = 'active' \| 'revoked' \| 'missing' \| 'unavailable'/)
  assert.match(auth, /if \(error\) \{[\s\S]*status: 'unavailable', profile: cached/)
  assert.match(auth, /restoreLastConfirmedProfile/)
  assert.match(auth, /localStorage\.setItem\(LAST_CONFIRMED_USER_KEY/)
  assert.doesNotMatch(auth, /if \(!user\.value\) \{[\s\S]{0,500}profile\.value = null/)
  assert.match(auth, /if \(!data\) \{[\s\S]*status: 'missing'/)
  assert.match(auth, /!profile\.value\.active[\s\S]*status: 'revoked'/)
  assert.match(guard, /if \(!navigator\.onLine \|\| !user\.value \|\| checking\) return/)
  assert.match(guard, /result\.status === 'revoked' \|\| result\.status === 'missing'/)
  assert.match(guard, /result\.status !== 'active'/)
  assert.match(middleware, /const refreshed = await refreshProfileAccess\(\)/)
})

test('offline identity transitions preserve encrypted local data', async () => {
  const sync = await read('plugins/sync.client.ts')
  const queue = await read('composables/useSyncQueue.ts')
  const recentPatients = await read('composables/useRecentPatientCache.ts')
  const offlineDb = await read('composables/useOfflineDb.ts')

  assert.match(sync, /if \(!userId\) return/)
  assert.doesNotMatch(sync, /navigator\.onLine && previousUserId && previousUserId !== userId/)
  assert.match(queue, /user\.value\?\.id \|\| state\.hydratedFor/)
  assert.match(recentPatients, /user\.value\?\.id \|\| \(profile\.value\?\.active \? profile\.value\.id/)
  assert.match(offlineDb, /const DB_VERSION = 3/)
  assert.match(offlineDb, /STORE_PROFILES = 'profile_cache'/)
  assert.match(offlineDb, /if \(oldVersion < 2\)/)
  assert.match(offlineDb, /cacheProfileSnapshot/)
  assert.match(offlineDb, /getCachedProfileSnapshot/)
})
