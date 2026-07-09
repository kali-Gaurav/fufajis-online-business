/**
 * Hash password using PBKDF2-HMAC-SHA256
 * Matches backend implementation exactly
 */
export async function hashPassword(
  password: string,
  salt: string,
  iterations = 10000
): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const saltBuf = encoder.encode(salt);

  const key = await globalThis.crypto.subtle.importKey(
    'raw',
    saltBuf,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  let result = await globalThis.crypto.subtle.sign('HMAC', key, data);
  for (let i = 1; i < iterations; i++) {
    result = await globalThis.crypto.subtle.sign('HMAC', key, result);
  }

  return Array.from(new Uint8Array(result))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Verify password against hash
 */
export async function verifyPassword(
  password: string,
  storedHash: string,
  salt: string
): Promise<boolean> {
  const computed = await hashPassword(password, salt);
  return computed === storedHash;
}

/**
 * Generate secure random token (256-bit)
 */
export function generateToken(): string {
  const array = new Uint8Array(32);
  globalThis.crypto.getRandomValues(array);
  return Array.from(array)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Hash token for storage (we store hashes, not plaintext)
 */
export async function hashToken(token: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(token);
  const hashBuffer = await globalThis.crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}
