export const paytrContractVersion = 1 as const;

export type InternalCurrencyCode = 'TRY';
export type PaytrCurrency = 'TL' | 'TRY' | 'USD' | 'EUR' | 'GBP' | 'RUB';

export interface PaymentCartItemInput {
  readonly productId: string;
  readonly quantity: number;
}

export interface PaymentCustomerInput {
  readonly email: string;
  readonly fullName: string;
  readonly phone: string;
  readonly address: string;
}

export interface CreatePaymentSessionInput {
  readonly contractVersion: typeof paytrContractVersion;
  readonly items: readonly PaymentCartItemInput[];
  readonly customer: PaymentCustomerInput;
}

export interface ServerCatalogProduct {
  readonly id: string;
  readonly displayName: string;
  readonly unitPriceMinor: number;
  readonly currencyCode: InternalCurrencyCode;
  readonly isActive: boolean;
}

export interface PricedOrderLine {
  readonly productId: string;
  readonly productName: string;
  readonly quantity: number;
  readonly unitPriceMinor: number;
  readonly lineTotalMinor: number;
}

export interface PricedCart {
  readonly currencyCode: InternalCurrencyCode;
  readonly subtotalMinor: number;
  readonly lines: readonly PricedOrderLine[];
}
