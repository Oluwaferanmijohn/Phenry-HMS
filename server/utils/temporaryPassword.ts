import { randomInt } from 'node:crypto'

const UPPER = 'ABCDEFGHJKMNPQRSTUVWXYZ'
const LOWER = 'abcdefghjkmnpqrstuvwxyz'
const DIGITS = '23456789'
const SYMBOLS = '!@#$%*-_+'
const ALL = UPPER + LOWER + DIGITS + SYMBOLS

function pick(chars: string) {
  return chars[randomInt(chars.length)]!
}

export function generateTemporaryPassword(length = 16) {
  if (length < 12) throw new Error('Temporary passwords must be at least 12 characters')
  const chars = [pick(UPPER), pick(LOWER), pick(DIGITS), pick(SYMBOLS)]
  while (chars.length < length) chars.push(pick(ALL))
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomInt(i + 1)
    ;[chars[i], chars[j]] = [chars[j]!, chars[i]!]
  }
  return chars.join('')
}
