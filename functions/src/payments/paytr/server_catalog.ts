import type {ServerCatalogProduct} from './payment_types.ts';

const products: readonly ServerCatalogProduct[] = [
  {
    id: 'phone_tripod',
    displayName: 'Telefon Tripodu',
    unitPriceMinor: 79900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'exercise_mat',
    displayName: 'Egzersiz Matı',
    unitPriceMinor: 64900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'resistance_band_set',
    displayName: 'Direnç Bandı Seti',
    unitPriceMinor: 49900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'mini_loop_band_set',
    displayName: 'Mini Loop Band Seti',
    unitPriceMinor: 27900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'foam_roller',
    displayName: 'Foam Roller',
    unitPriceMinor: 54900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'adjustable_dumbbell',
    displayName: 'Ayarlanabilir Dambıl',
    unitPriceMinor: 249900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'training_tshirt',
    displayName: 'Antrenman Tişörtü',
    unitPriceMinor: 44900,
    currencyCode: 'TRY',
    isActive: true,
  },
  {
    id: 'training_shorts',
    displayName: 'Antrenman Şortu',
    unitPriceMinor: 39900,
    currencyCode: 'TRY',
    isActive: true,
  },
];

export const serverCatalogById: ReadonlyMap<string, ServerCatalogProduct> =
  new Map(products.map((product) => [product.id, product]));
