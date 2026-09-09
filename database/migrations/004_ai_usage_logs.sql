create table if not exists ai_usage_logs (
  id uuid primary key default gen_random_uuid(),
  prompt_name text not null, prompt_version text not null, model text not null,
  prompt_tokens int, completion_tokens int, total_tokens int,
  estimated_cost_usd numeric, created_at timestamptz default now()
);
