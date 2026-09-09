# FUSKAMO — configuration checklist

## Required to run the core app

### Flutter `.env` (project root)
```env
SUPABASE_URL=YOUR_SUPABASE_PROJECT_URL
SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
BACKEND_BASE_URL=http://YOUR_BACKEND_HOST:8080
BACKEND_API_KEY=GENERATE_A_LONG_RANDOM_SECRET
```

### Backend `backend/.env`
```env
PORT=8080
NODE_ENV=development
BACKEND_API_KEY=THE_SAME_SECRET_AS_FLUTTER
SUPABASE_URL=YOUR_SUPABASE_PROJECT_URL
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVER_ONLY_SERVICE_ROLE_KEY
SUPABASE_JWT_SECRET=YOUR_SUPABASE_JWT_SECRET
SUPABASE_DB_URL=YOUR_SUPABASE_POSTGRES_CONNECTION_STRING
```

Run database migrations `001` through the latest migration in `database/migrations/` against the same Supabase project.

## Optional feature credentials

### M-Pesa Boost
```env
MPESA_ENV=sandbox
MPESA_CONSUMER_KEY=YOUR_DARAJA_CONSUMER_KEY
MPESA_CONSUMER_SECRET=YOUR_DARAJA_CONSUMER_SECRET
MPESA_SHORTCODE=YOUR_SHORTCODE
MPESA_PASSKEY=YOUR_PASSKEY
MPESA_CALLBACK_URL=https://YOUR_PUBLIC_BACKEND_DOMAIN/api/mpesa/callback
```
Refund credentials are only needed if the refund/B2C path is enabled:
```env
MPESA_INITIATOR_NAME=YOUR_INITIATOR
MPESA_SECURITY_CREDENTIAL=YOUR_SECURITY_CREDENTIAL
```

### AI scouting note
```env
AI_PROVIDER_BASE_URL=https://api.openai.com/v1
AI_PROVIDER_API_KEY=YOUR_AI_API_KEY
AI_MODEL=YOUR_MODEL
```

### Push notifications
Create a Firebase project and add the platform configuration files. Backend push delivery also requires:
```env
FIREBASE_SERVICE_ACCOUNT_JSON=YOUR_FIREBASE_SERVICE_ACCOUNT_JSON_AS_ONE_LINE
```

### Redis
```env
REDIS_URL=YOUR_REDIS_URL
```

### CORS for deployed web/admin clients
```env
CORS_ALLOWED_ORIGINS=https://YOUR_ADMIN_DOMAIN,https://YOUR_WEB_DOMAIN
```

### SMS (only if the SMS service is enabled)
```env
AT_USERNAME=YOUR_AFRICAS_TALKING_USERNAME
AT_API_KEY=YOUR_AFRICAS_TALKING_API_KEY
```

### Email (only if email delivery is enabled)
```env
SMTP_HOST=YOUR_SMTP_HOST
SMTP_PORT=587
SMTP_USER=YOUR_SMTP_USERNAME
SMTP_PASS=YOUR_SMTP_PASSWORD
EMAIL_FROM=YOUR_FROM_ADDRESS
```

## Not required yet

Actual cloud video hosting/CDN credentials are intentionally not required because FUSKAMO video hosting is currently gated as **COMING SOON**.

## Android release signing

For a Play Store release, generate your own upload keystore and create `android/key.properties` from the example. Do not use credentials embedded in documentation or examples.

## Never put these in Flutter

Never put these server-only values in the Flutter `.env`:
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `SUPABASE_DB_URL`
- `MPESA_CONSUMER_SECRET`
- `MPESA_PASSKEY`
- `AI_PROVIDER_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- SMTP passwords

## Local Android note

If Flutter runs on a physical Android phone, `http://localhost:8080` points to the phone itself. Use the computer's LAN IP (for example `http://192.168.x.x:8080`) or a deployed HTTPS backend.
