/**
 * Development fallback for Supabase's generated database types.
 *
 * Replace this file in CI/development with the output of:
 *   supabase gen types typescript --linked > types/database.types.ts
 *
 * Keeping a schema-shaped fallback prevents the Nuxt Supabase module from
 * collapsing every table and RPC to `never` when a developer has not linked a
 * Supabase project yet. Runtime authorization remains enforced by PostgreSQL
 * RLS and the guarded RPCs in supabase/migrations.
 */
// `any` is deliberate only in this fallback: a made-up relationship map is
// worse than no static schema because it rejects valid embedded selects. The
// linked `supabase gen types` output replaces this alias in real CI.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Database = any
