export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

export function successResponse(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    headers: corsHeaders,
    status,
  });
}

export function errorResponse(
  message: string,
  error_code = 'UNKNOWN_ERROR',
  status = 400,
  debug?: any
): Response {
  return new Response(
    JSON.stringify({ success: false, message, error_code, debug }),
    {
      headers: corsHeaders,
      status,
    }
  );
}
