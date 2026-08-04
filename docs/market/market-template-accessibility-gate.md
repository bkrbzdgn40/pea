# Market Template Accessibility Gate

Market Template v1 must remain usable without relying on visual-only cues.

## Required behavior

- Product cards expose one concise semantic action containing product name and price.
- Product visuals on the detail screen are announced as images.
- The cart action announces the current total item count.
- Increment, decrement, and remove controls name the affected product.
- Quantity changes are exposed through a live semantic value.
- Interactive controls preserve a minimum 48 × 48 logical-pixel target.
- Catalog, cart, and checkout remain scrollable at 320 × 568 with 2× text scaling.
- Turkish and English strings are supplied through `AppLocalizations`; market widgets do not embed user-visible copy.

## Non-goals

This gate does not enable payment, order creation, address capture, remote catalog loading, or background work.
