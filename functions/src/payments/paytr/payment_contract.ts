import {
  paytrContractVersion,
  type CreatePaymentSessionInput,
  type PaymentCartItemInput,
  type PaymentCustomerInput,
} from './payment_types.ts';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class PaymentContractError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'PaymentContractError';
    this.code = code;
  }
}

export function parseCreatePaymentSessionInput(
  raw: unknown,
): CreatePaymentSessionInput {
  const object = readObject(raw, 'request body');
  assertAllowedKeys(
    object,
    ['contractVersion', 'items', 'customer'],
    'request body',
  );
  const contractVersion = object.contractVersion;
  if (contractVersion !== paytrContractVersion) {
    throw new PaymentContractError(
      'unsupported_contract_version',
      `contractVersion must be ${paytrContractVersion}.`,
    );
  }

  const items = parseItems(object.items);
  const customer = parseCustomer(object.customer);

  return {contractVersion, items, customer};
}

function parseItems(raw: unknown): readonly PaymentCartItemInput[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new PaymentContractError(
      'invalid_items',
      'items must contain at least one cart line.',
    );
  }
  if (raw.length > 20) {
    throw new PaymentContractError(
      'too_many_items',
      'items cannot contain more than 20 cart lines.',
    );
  }

  return raw.map((item, index) => {
    const object = readObject(item, `items[${index}]`);
    assertAllowedKeys(
      object,
      ['productId', 'quantity'],
      `items[${index}]`,
    );
    const productId = readString(
      object.productId,
      `items[${index}].productId`,
      64,
    );
    const quantity = object.quantity;
    if (
      typeof quantity !== 'number' ||
      !Number.isInteger(quantity) ||
      quantity < 1 ||
      quantity > 10
    ) {
      throw new PaymentContractError(
        'invalid_quantity',
        `items[${index}].quantity must be an integer between 1 and 10.`,
      );
    }
    return {productId, quantity};
  });
}

function parseCustomer(raw: unknown): PaymentCustomerInput {
  const object = readObject(raw, 'customer');
  assertAllowedKeys(
    object,
    ['email', 'fullName', 'phone', 'address'],
    'customer',
  );
  const email = readString(object.email, 'customer.email', 100);
  if (!emailPattern.test(email) || /[^\x00-\x7F]/.test(email)) {
    throw new PaymentContractError(
      'invalid_email',
      'customer.email must be a valid ASCII email address.',
    );
  }

  return {
    email,
    fullName: readString(object.fullName, 'customer.fullName', 60),
    phone: readString(object.phone, 'customer.phone', 20),
    address: readString(object.address, 'customer.address', 400),
  };
}

function readObject(
  raw: unknown,
  fieldName: string,
): Record<string, unknown> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new PaymentContractError(
      'invalid_object',
      `${fieldName} must be a JSON object.`,
    );
  }
  return raw as Record<string, unknown>;
}

function readString(
  raw: unknown,
  fieldName: string,
  maxLength: number,
): string {
  if (typeof raw !== 'string') {
    throw new PaymentContractError(
      'invalid_string',
      `${fieldName} must be a string.`,
    );
  }
  const value = raw.trim();
  if (value.length === 0 || value.length > maxLength) {
    throw new PaymentContractError(
      'invalid_string_length',
      `${fieldName} must contain between 1 and ${maxLength} characters.`,
    );
  }
  return value;
}

function assertAllowedKeys(
  object: Record<string, unknown>,
  allowedKeys: readonly string[],
  fieldName: string,
): void {
  const allowed = new Set(allowedKeys);
  const unexpected = Object.keys(object).filter((key) => !allowed.has(key));
  if (unexpected.length > 0) {
    throw new PaymentContractError(
      'unexpected_field',
      `${fieldName} contains unsupported fields: ${unexpected.join(', ')}.`,
    );
  }
}
