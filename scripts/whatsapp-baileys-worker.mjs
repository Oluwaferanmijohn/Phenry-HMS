import makeWASocket, { DisconnectReason, useMultiFileAuthState } from '@whiskeysockets/baileys'
import pino from 'pino'
import { loadEnvFile } from 'node:process'

// Unlike Nuxt, a plain Node script does not automatically load the project's
// .env file. Load it before reading any worker settings so the server and
// worker use the same secret.
try {
  loadEnvFile()
} catch (error) {
  if (error?.code !== 'ENOENT') throw error
}

const configuredAppUrl = String(process.env.APP_BASE_URL || '').trim().replace(/\/$/, '')
const appUrls = configuredAppUrl
  ? [configuredAppUrl]
  : [
      'http://localhost:3027',
      'http://127.0.0.1:3027',
      'http://[::1]:3027',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://[::1]:3000',
    ]
let appUrl = appUrls[0]
const workerSecret = process.env.WHATSAPP_WORKER_SECRET
const authDirectory = process.env.BAILEYS_AUTH_DIR || '.baileys-auth'
const defaultCountryCode = String(process.env.WHATSAPP_DEFAULT_COUNTRY_CODE || '234').replace(/\D/g, '')
const pollMilliseconds = Math.max(15_000, Number(process.env.WHATSAPP_POLL_MS || 30_000))
if (!workerSecret) throw new Error('WHATSAPP_WORKER_SECRET is missing. Add it to the project .env file, restart Nuxt, then run this worker again.')

const logger = pino({ level: process.env.WHATSAPP_LOG_LEVEL || 'info' })
let socket
let connected = false
let processing = false

function jidFor(phone) {
  const raw = String(phone || '').trim()
  let digits = raw.replace(/\D/g, '')
  if (raw.startsWith('0')) digits = defaultCountryCode + digits.slice(1)
  if (digits.length < 8 || digits.length > 15) throw new Error('Invalid WhatsApp phone number')
  return `${digits}@s.whatsapp.net`
}
async function api(path, options = {}) {
  const response = await fetch(`${appUrl}${path}`, { ...options, headers: { 'content-type': 'application/json', 'x-whatsapp-worker-secret': workerSecret, ...(options.headers || {}) } })
  if (!response.ok) throw new Error(`Reminder API ${response.status}: ${await response.text()}`)
  return response.json()
}
const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds))
async function waitForApp() {
  let announced = false
  while (true) {
    let lastError
    for (const candidate of appUrls) {
      appUrl = candidate
      try {
        await api('/api/internal/whatsapp/health')
        logger.info({ appUrl }, 'Nuxt app is reachable; starting WhatsApp connection')
        return
      } catch (error) {
        lastError = error
      }
    }
    if (!announced) {
      logger.warn({ attempted: appUrls, error: String(lastError?.message || lastError) }, 'Nuxt app is not reachable. Start npm run dev in another terminal; the worker will keep waiting.')
      announced = true
    }
    await delay(5_000)
  }
}
async function report(id, success, providerMessageId = null, error = null) {
  await api('/api/internal/whatsapp/result', { method: 'POST', body: JSON.stringify({ id, success, providerMessageId, error }) })
}
async function publishStatus(status, qr = null, error = null) {
  try {
    await api('/api/internal/whatsapp/status', { method: 'POST', body: JSON.stringify({ status, qr, error, accountLabel: socket?.user?.id || null }) })
  } catch (publishError) {
    logger.warn({ error: String(publishError?.message || publishError) }, 'Could not publish WhatsApp gateway status')
  }
}
async function processQueue() {
  if (!connected || !socket || processing) return
  processing = true
  try {
    const { reminders = [] } = await api('/api/internal/whatsapp/due')
    for (const reminder of reminders) {
      try {
        const result = await socket.sendMessage(jidFor(reminder.phone), { text: reminder.body })
        await report(reminder.id, true, result?.key?.id || null)
      } catch (error) {
        const message = String(error?.message || error).slice(0, 500)
        await report(reminder.id, false, null, message)
        logger.warn({ reminderId: reminder.id, error: message }, 'WhatsApp reminder failed')
      }
    }
  } catch (error) { logger.error({ error: String(error?.message || error) }, 'Reminder queue request failed') }
  finally { processing = false }
}
async function connect() {
  const { state, saveCreds } = await useMultiFileAuthState(authDirectory)
  socket = makeWASocket({ auth: state, logger, markOnlineOnConnect: false, syncFullHistory: false })
  socket.ev.on('creds.update', saveCreds)
  socket.ev.on('connection.update', ({ connection, lastDisconnect, qr }) => {
    if (qr) { logger.info('WhatsApp pairing QR published to the admin dashboard'); void publishStatus('pairing', qr) }
    if (connection === 'open') { connected = true; logger.info('WhatsApp reminder worker connected'); void publishStatus('connected'); void processQueue() }
    if (connection === 'close') {
      connected = false
      const code = lastDisconnect?.error?.output?.statusCode
      if (code === DisconnectReason.loggedOut) { logger.error('WhatsApp logged out. Remove the private auth directory and pair again.'); void publishStatus('logged_out', null, 'The linked WhatsApp session was logged out.') }
      else { void publishStatus('disconnected', null, String(lastDisconnect?.error?.message || 'Connection closed')); setTimeout(() => void connect(), 5_000) }
    }
  })
}
await waitForApp()
await connect()
setInterval(() => void processQueue(), pollMilliseconds)
