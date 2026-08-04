# Market Preview Catalog Contract

The market remains a supporting template for the movement-analysis product. The
preview catalog is bundled with the application and is read only after the
Market route opens.

## Current source

```text
assets/market/preview_catalog.json
```

The document uses schema version `1`:

```json
{
  "schemaVersion": 1,
  "products": [
    {
      "id": "phone_tripod",
      "category": "setup",
      "priceMinor": 79900,
      "currencyCode": "TRY",
      "isFeatured": true,
      "imageAssetPath": "assets/market/products/phone_tripod.webp"
    }
  ]
}
```

## Field rules

- `id` is a non-empty, unique product identifier.
- `category` must match a supported `MarketCategory.id` value.
- `priceMinor` is a non-negative integer in the currency's minor unit.
- `currencyCode` is an uppercase three-letter currency code.
- `isFeatured` is optional and defaults to `false`.
- `imageAssetPath` is optional, but when present it must point to a bundled `.webp` file under `assets/market/products/`.
- the catalog must contain at least one product.

Product names and descriptions remain localized in the application during the
template phase. The optional image path refers only to an optimized bundled
preview thumbnail. Remote images, stock, variants, discounts, delivery,
payment, and orders are deliberately outside this schema.

## Future replacement boundary

A later operations service may replace the bundled repository with a remote
implementation. Presentation code must continue to depend only on
`MarketCatalogRepository`; it must not know whether products came from an asset,
Firestore, or another backend.

The mobile application must not trust future client-supplied prices for real
checkout. This contract is display-only until a server-authoritative commerce
backend is approved.
