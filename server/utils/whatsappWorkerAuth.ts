import { timingSafeEqual } from 'node:crypto'

export function assertWhatsappWorker(event: any) {
  const configured = String(useRuntimeConfig(event).whatsappWorkerSecret || '')
  const supplied = String(getHeader(event, 'x-whatsapp-worker-secret') || '')
  if (!configured || !supplied) throw createError({ statusCode: 503, statusMessage: 'WhatsApp worker authentication is not configured' })
  const expected = Buffer.from(configured)
  const received = Buffer.from(supplied)
  if (expected.length !== received.length || !timingSafeEqual(expected, received)) throw createError({ statusCode: 401, statusMessage: 'Invalid WhatsApp worker credential' })
}
