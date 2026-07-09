import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js';
import { corsHeaders, successResponse, errorResponse } from './utils/response.ts';
import { handleLogin } from './handlers/login.ts';
import { handlePasswordSetup } from './handlers/password_setup.ts';
import { handlePasswordChange } from './handlers/password_change.ts';
import { AuthenticatedContext } from './types/index.ts';

// Initialize Supabase client (runs with service_role key for full access)
const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const supabase = createClient(supabaseUrl, supabaseKey);

// Initialize Upstash Redis client
import { Redis } from 'npm:@upstash/redis';
const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_REST_URL') || '',
  token: Deno.env.get('UPSTASH_REDIS_REST_TOKEN') || '',
});

serve(async (req: Request) => {
  const { pathname } = new URL(req.url);

  try {
    // CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // 1. Generate Correlation ID and Idempotency Key
    const correlationId = req.headers.get('X-Correlation-ID') || crypto.randomUUID();
    const idempotencyKey = req.headers.get('Idempotency-Key') || crypto.randomUUID();

    // 2. Extract IP and user agent
    const ip = req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip') || 'unknown';
    const userAgent = req.headers.get('user-agent') || 'unknown';

    // 3. JWT Middleware (For protected routes)
    let authContext: AuthenticatedContext | null = null;
    if (pathname.endsWith('/auth/password-setup') || pathname.endsWith('/auth/password-change')) {
      const authHeader = req.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return errorResponse('Unauthorized - Missing or invalid token', 'UNAUTHORIZED', 401);
      }
      
      const token = authHeader.replace('Bearer ', '');
      
      // Verify JWT using Supabase Auth
      // Note: We create a fresh client with the user's token to verify it
      const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') || '', {
        global: { headers: { Authorization: authHeader } }
      });
      
      const { data: { user }, error: userError } = await userClient.auth.getUser();
      
      if (userError || !user) {
        return errorResponse('Unauthorized - Invalid or expired token', 'UNAUTHORIZED', 401);
      }

      // Fetch role from privileged_credentials for RBAC
      const { data: cred, error: credError } = await supabase
        .rpc('rpc_get_user_role', { p_user_id: user.id });
        
      if (credError) {
        console.error('Error fetching role:', credError);
        return errorResponse('Internal Server Error', 'INTERNAL_ERROR', 500);
      }
        
      if (!cred || cred.status !== 'active') {
        return errorResponse('Unauthorized - Account revoked or not found', 'UNAUTHORIZED', 403);
      }

      authContext = {
        user_id: user.id,
        role: cred.role,
        correlation_id: correlationId,
        idempotency_key: idempotencyKey
      };
    }

    // Route requests
    if (pathname.endsWith('/auth/login') && req.method === 'POST') {
      const body = await req.json();
      const result = await handleLogin(supabase, redis, {
        email: body.email,
        password: body.password,
        device_id: body.device_id,
        device_name: body.device_name,
        ip_address: ip,
        user_agent: userAgent,
        app_version: body.app_version,
        platform: body.platform
      }, correlationId, idempotencyKey);
      return result.success ? successResponse(result) : errorResponse(result.message, result.error_code, 401, (result as any).debug);
    }

    if (pathname.endsWith('/auth/password-setup') && req.method === 'POST') {
      const body = await req.json();
      const result = await handlePasswordSetup(supabase, authContext!, body);
      return result.success ? successResponse(result) : errorResponse(result.message, result.error_code, 400);
    }

    if (pathname.endsWith('/auth/password-change') && req.method === 'POST') {
      const body = await req.json();
      const result = await handlePasswordChange(supabase, authContext!, body);
      return result.success ? successResponse(result) : errorResponse(result.message, result.error_code, 400);
    }

    return new Response(
      JSON.stringify({ error: 'Endpoint not found' }),
      { headers: corsHeaders, status: 404 }
    );
  } catch (error: any) {
    console.error('Unhandled Edge Function Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message || String(error), stack: error.stack }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
