create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  checkout_request_id text unique not null,
  merchant_request_id text,
  phone_number text not null,
  amount numeric not null,
  account_reference text,
  status text not null default 'pending' check (status in ('pending','completed','failed')),
  mpesa_receipt_number text,
  result_desc text,
  created_at timestamptz default now()
);
create index if not exists idx_transactions_status on transactions(status);
create index if not exists idx_transactions_phone on transactions(phone_number);
