// Resolves cycle_manager_id -> nurse full_name as a plain follow-up query
// instead of a `cycle_manager:cycle_manager_id(full_name)` embed.
//
// Deliberately NOT using the embed here even though cycle_manager_id does
// have a real FK to profiles.id: PostgREST needs to pick up a brand-new FK
// in its schema cache before it can resolve an embed through it, and that
// cache reload doesn't always happen immediately after a DDL change made
// via the SQL editor (a manual "Reload schema cache" / `NOTIFY pgrst,
// 'reload schema'` may be needed). A plain INSERT/UPDATE of the scalar
// column works fine even with a stale cache, which is exactly the gap that
// made a cycle look like it "saved successfully" while still not showing
// up in any list querying it via the embed. Splitting this into two plain
// queries removes that dependency entirely — same reasoning as the
// bio_details/assigned_doctor fix this mirrors.
export async function resolveCycleManagerNames(supabase: any, cycleManagerIds: (string | null | undefined)[]): Promise<Map<string, string>> {
  const ids = [...new Set(cycleManagerIds.filter(Boolean))] as string[]
  if (!ids.length) return new Map()
  const { data } = await supabase.from('profiles').select('id, full_name').in('id', ids)
  return new Map((data || []).map((p: any) => [p.id, p.full_name]))
}
