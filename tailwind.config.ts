import type { Config } from 'tailwindcss'

// Token values ported 1:1 from the prototype's css/styles.css :root block.
// The prototype's own component classes (.card, .btn, .badge, etc.) are
// preserved verbatim in assets/css/main.css for pixel fidelity — this
// Tailwind config exists so any new production-only UI (mobile read-only
// mode, loading skeletons, etc.) can pull from the same palette rather than
// inventing new colors.
export default <Partial<Config>>{
  content: [
    './components/**/*.{vue,js,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './composables/**/*.ts',
    './app.vue',
  ],
  theme: {
    extend: {
      colors: {
        bg: '#F7F8FC',
        card: '#FFFFFF',
        border: { DEFAULT: '#E6E9F1', strong: '#D6DAE6' },
        text: { 900: '#101828', 700: '#344054', 500: '#667085', 400: '#98A2B3' },
        navy: { 950: '#141D2E', 900: '#1B2740', 800: '#24314C', 700: '#324160' },
        sidebar: { text: '#93A0BC', active: '#FFFFFF' },
        brand: { 700: '#0E5F91', 600: '#1479B8', 500: '#2E93D1', 100: '#D6ECF9', 50: '#EEF7FC' },
        success: { 600: '#15803D', 500: '#16A34A', 50: '#E7F8ED' },
        warn: { 600: '#B45309', 500: '#D97706', 50: '#FEF3E2' },
        danger: { 600: '#B91C1C', 500: '#DC2626', 50: '#FDECEC' },
        accent: { 600: '#6D28D9', 50: '#F1EBFE' },
      },
      borderRadius: { sm: '6px', md: '10px', lg: '14px' },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        sm: '0 1px 2px rgba(16,24,40,0.06)',
        md: '0 4px 16px rgba(16,24,40,0.08)',
      },
    },
  },
  plugins: [],
}
