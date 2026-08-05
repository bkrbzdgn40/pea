import {randomUUID} from 'node:crypto';
import {isIP} from 'node:net';

export class PaymentRequestContextError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'PaymentRequestContextError';
    this.code = code;
  }
}

export function readBearerToken(raw: string | undefined): string {
  if (typeof raw !== 'string') {
    throw new PaymentRequestContextError(
      'unauthenticated',
      'Authorization bearer token is required.',
    );
  }

  const match = /^Bearer\s+([^\s]+)$/i.exec(raw.trim());
  if (match === null) {
    throw new PaymentRequestContextError(
      'unauthenticated',
      'Authorization bearer token is invalid.',
    );
  }
  const token = match[1];
  if (token === undefined) {
    throw new PaymentRequestContextError(
      'unauthenticated',
      'Authorization bearer token is invalid.',
    );
  }
  return token;
}

export function readClientIp(
  forwardedFor: string | string[] | undefined,
  fallbackIp: string | undefined,
): string {
  const firstForwarded = Array.isArray(forwardedFor)
    ? forwardedFor[0]
    : forwardedFor?.split(',')[0];
  const candidates = [firstForwarded, fallbackIp];

  for (const candidate of candidates) {
    const normalized = normalizeIp(candidate);
    if (normalized !== null) {
      return normalized;
    }
  }

  throw new PaymentRequestContextError(
    'invalid_client_ip',
    'A valid client IP address is required.',
  );
}

export function readRequestId(
  cloudTraceContext: string | string[] | undefined,
): string {
  const raw = Array.isArray(cloudTraceContext)
    ? cloudTraceContext[0]
    : cloudTraceContext;
  const traceId = raw?.split('/')[0]?.trim();
  if (traceId !== undefined && /^[a-fA-F0-9]{16,64}$/.test(traceId)) {
    return traceId;
  }
  return randomUUID();
}

function normalizeIp(raw: string | undefined): string | null {
  if (raw === undefined) {
    return null;
  }

  let candidate = raw.trim();
  if (candidate.startsWith('::ffff:')) {
    const mappedIpv4 = candidate.slice('::ffff:'.length);
    if (isIP(mappedIpv4) === 4) {
      return mappedIpv4;
    }
  }

  if (candidate.startsWith('[')) {
    const closingBracket = candidate.indexOf(']');
    if (closingBracket > 0) {
      candidate = candidate.slice(1, closingBracket);
    }
  }

  return isIP(candidate) === 0 ? null : candidate;
}
