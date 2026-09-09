require('dotenv').config();

function required(name) {
  return process.env[name] || '';
}

module.exports = {
  port: process.env.PORT || 8080,
  nodeEnv: process.env.NODE_ENV || 'development',
  backendApiKey: required('BACKEND_API_KEY'),
  // Where admin-web/ is deployed — used as the default redirect for
  // Supabase's admin-invite emails. Optional: invite() also accepts an
  // explicit redirectTo per-call, so this is just the sane default.
  adminConsoleUrl: process.env.ADMIN_CONSOLE_URL || '',

  supabase: {
    url: required('SUPABASE_URL'),
    serviceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
    jwtSecret: required('SUPABASE_JWT_SECRET'),
    // Raw Postgres connection string (Supabase → Project Settings → Database)
    // — needed for true transactions/pooling that PostgREST (supabase-js)
    // can't do. Different from the REST URL above.
    dbConnectionString: required('SUPABASE_DB_URL'),
  },

  cors: {
    allowedOrigins: (process.env.CORS_ALLOWED_ORIGINS || '').split(',').filter(Boolean),
  },

  redis: {
    url: process.env.REDIS_URL || '',
  },

  mpesa: {
    env: process.env.MPESA_ENV || 'sandbox',
    consumerKey: required('MPESA_CONSUMER_KEY'),
    consumerSecret: required('MPESA_CONSUMER_SECRET'),
    shortcode: required('MPESA_SHORTCODE'),
    passkey: required('MPESA_PASSKEY'),
    callbackUrl: required('MPESA_CALLBACK_URL'),
    // Only needed for refunds (B2C reversal) — separate credential set
    // Safaricom issues specifically for that, distinct from paybill auth.
    initiatorName: required('MPESA_INITIATOR_NAME'),
    securityCredential: required('MPESA_SECURITY_CREDENTIAL'),
  },

  ai: {
    baseUrl: process.env.AI_PROVIDER_BASE_URL || '',
    apiKey: required('AI_PROVIDER_API_KEY'),
    model: process.env.AI_MODEL || 'gpt-4o-mini',
    // Optional secondary provider — used only if the primary call fails.
    fallbackBaseUrl: process.env.AI_FALLBACK_BASE_URL || '',
    fallbackApiKey: required('AI_FALLBACK_API_KEY'),
    fallbackModel: process.env.AI_FALLBACK_MODEL || '',
  },

  notifications: {
    atUsername: process.env.AT_USERNAME || '',
    atApiKey: required('AT_API_KEY'),
    smtpHost: process.env.SMTP_HOST || '',
    smtpPort: parseInt(process.env.SMTP_PORT || '587', 10),
    smtpUser: process.env.SMTP_USER || '',
    smtpPass: required('SMTP_PASS'),
    emailFrom: process.env.EMAIL_FROM || '',
    firebaseServiceAccountJson: required('FIREBASE_SERVICE_ACCOUNT_JSON'),
  },

  isConfigured: {
    supabase: !!(required('SUPABASE_URL') && required('SUPABASE_SERVICE_ROLE_KEY')),
    mpesa: !!(required('MPESA_CONSUMER_KEY') && required('MPESA_CONSUMER_SECRET') && required('MPESA_SHORTCODE')),
    ai: !!required('AI_PROVIDER_API_KEY'),
    jwt: !!required('SUPABASE_JWT_SECRET'),
    redis: !!process.env.REDIS_URL,
    db: !!required('SUPABASE_DB_URL'),
  },
};
