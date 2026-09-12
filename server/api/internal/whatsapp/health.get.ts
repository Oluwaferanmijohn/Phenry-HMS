import { assertWhatsappWorker } from '~/server/utils/whatsappWorkerAuth'

export default defineEventHandler((event) => {
  assertWhatsappWorker(event)
  return { ok: true }
})
