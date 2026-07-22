# 03 - User Guide

> Guide for **end users** (store customers) and **administrators** who manage the catalog
> and orders. Covers RNCP competency **C2.4.1**.
>
> Note: the product UI itself is in French (target audience: French customers). Button and menu labels below are
> quoted exactly as they appear on screen, in French.

---

## Part A - Customer Journey

### A.1 - Browsing the catalog

1. Open <https://gauthierfitness.fr>.
2. The homepage shows featured products.
3. The menu allows filtering by:
    - **Gender** (men, women, unisex)
    - **Category** (t-shirts, leggings, accessories, nutrition, etc.)
    - **Tag** (new arrivals, bestsellers)
4. Clicking a product opens the **detail page** with:
    - Image gallery (main image + hover)
    - Variant selector (color or flavor depending on the product)
    - Size / format / volume selector
    - Stock indicator
    - **"Personnaliser"** (Customize) button if the product is customizable
    - **"Ajouter au panier"** (Add to cart) button

### A.2 - Customizing a product (2D or 3D)

Available on customizable clothing and accessories. The editor is 2D (Konva canvas) or 3D (Three.js, real-time
render on the garment mesh) depending on the product's configuration - the customer sees no toggle, each product
simply opens in its configured mode.

1. Click **"Personnaliser ce produit"** on the product page.
2. The editor opens with a live, real-time view of the product (no separate preview step - every change is
   reflected immediately).
3. Three tabs give access to the tools:
    - **Style** - garment color, decorative template, patterns/gradients
    - **Texte** - player name, player number, free text
    - **Médias** - chest logo, free image upload (≤ 5 MB), or an AI-generated design from a text prompt
      *(if enabled on the product)*
4. Text and image/logo elements can be **repositioned by drag** directly on the render. There is currently
   **no resize handle** - uploaded/generated images have a fixed size (see
   [01-architecture.md § 8](./01-architecture.md#8-known-limitations-and-evolution-areas)), planned for V2.
5. Click **"Brouillon"** to save progress without adding to the cart, **"Réinitialiser"** to start over, or
   **"Ajouter au panier"** (Add to cart) once satisfied - the customization is saved and linked to the cart line.

Guard rails: a non-numeric player number, a blocklisted term in the player name/free text, or an uploaded/generated
image flagged by content moderation (standard categories or a dedicated weapons/drugs/hate-symbols check) are all
rejected with an explicit error message before they can be added to the cart.

### A.3 - AI design generation

On products that allow AI, from the **Médias** tab:

1. Enter a descriptive prompt in the **"Générer un design par IA"** field (10 characters minimum, 5000 maximum).
    - Example: *"A stylized dragon in black and gold, Japanese aesthetic, on a transparent background"*
2. Click **"Générer le design"** - the request typically takes 20 to 40 seconds (`gpt-image-1`, `quality: medium`).
3. The generated image appears in the editor, positioned the same way as an uploaded image (drag to reposition).
4. If the result isn't satisfactory, regenerate with a refined prompt.

> **Note** - Generated designs are saved to the user's account and reusable.

### A.4 - Managing the cart

1. Click the cart icon at the top right.
2. For each line:
    - View the subtotal, variant, and any customization
    - Change the quantity with the `+` / `−` buttons
    - Remove the line with the trash icon
3. The subtotal and delivery time are shown at the bottom.
4. Click **"Passer commande"** (Place order) to go to checkout.

### A.5 - Placing an order

1. Log in / sign up if not already logged in.
2. Enter the **shipping address** (first name, last name, address, zip code, city, country, optional phone).
3. Click **"Payer"** (Pay) — the Stripe Elements form appears.
4. Enter the card details (Stripe handles **3D-Secure** automatically if the bank requires it).
5. Confirm the payment.
6. **Redirect to the confirmation page** with an order summary.
7. Confirmation email sent right after.

### A.6 - Tracking orders

1. Menu **"Mon compte" → "Mes commandes"** (My account → My orders).
2. List of orders in reverse chronological order.
3. For each order:
    - Number, date, status (`new`, `processing`, `shipped`, `delivered`, `canceled`)
    - Total incl. tax
    - Delivery tracking (tracking number + carrier link when available)
4. Click an order to see the detail (lines, unit price, customizations).
5. On every status change → automatic email.

### A.7 - Contacting support

Contact form in the footer: <https://gauthierfitness.fr/contact>

- Name, email, subject (optional), message required.
- Limited to 5 submissions per minute per IP (anti-spam).
- The message is delivered to the configured support email (`hortense.gauthier2002@gmail.com`).

---

## Part B - Admin Back-Office

### B.1 - Accessing the admin panel

1. Log in with an account that has the `admin` role.
2. Go to <https://gauthierfitness.fr/admin>.
3. The dashboard shows overall stats: active products, orders for the day/week/month, revenue, stock alerts.

### B.2 - Managing the catalog

#### Listing / searching products

- **"Produits"** (Products) menu → paginated table (20 / page) with search by name or SKU.
- Filters: `active`, `customizable`.
- Columns: image, name, SKU, price incl. tax, status, options.

#### Creating a product

- **"Nouveau produit"** (New product) button → form with:
    - Identifiers: name, SKU (unique), description
    - Price excl. tax, price incl. tax, VAT (usually 20%)
    - Flags: active, customizable, mode (`2d` / `3d`), allow text / image / AI
    - Options (size / format / volume) - addable in a single step
- On creation, the slug is generated automatically from the name and deduplicated on conflict.

#### Editing / deleting a product

- Click a row → edit page.
- All fields are editable except the slug.
- Deletion is possible - existing orders keep their snapshot and remain viewable.
- **"Activer / Désactiver"** (Activate / Deactivate) button to temporarily hide from the public catalog.

### B.3 - Managing stock

#### Overview

- **"Stock"** menu → paginated list of all products with their total quantity (sum of lots).
- Search by name / SKU.
- Visual filter: products **out of stock** (qty = 0) or **low stock** (qty < 5).

#### Product detail

- Click a product → detail view:
    - **Global stock** (lots without a variant) - e.g. for unit nutrition items
    - **Stock by option** (lots tied to a size / flavor)
    - For each lot: number, quantity, initial quantity, expiration date
    - Lots sorted FIFO (nearest expiration first)

#### Restocking

- **"Nouveau lot"** (New lot) button → form:
    - Option (optional, otherwise global stock)
    - Lot number (required, unique)
    - Initial quantity
    - Expiration date (optional, must be in the future)
- On creation, an `in` stock movement is automatically tracked.

#### Correcting a lot

- **"Ajuster"** (Adjust) button on a lot → enter the new quantity and a required reason.
- A `correction` stock movement is tracked with the delta.
- Used for: breakage, physical inventory, data entry error.

#### Movement history

- **"Historique"** (History) button on a product → paginated table (30 / page) with:
    - Date, type (`in` / `out` / `correction`), quantity, reason, related lot
    - Outgoing movements (`out`) automatically linked to the order that consumed the stock.

### B.4 - Managing orders

#### Listing / searching

- **"Commandes"** (Orders) menu → paginated table (20 / page).
- Filters: status, search by customer email/name/first name.
- Columns: number, customer, total incl. tax, payment status, order status, date.

#### Order detail

- Click an order → detail view:
    - Customer (firstname, lastname, email, phone)
    - Lines (product, variant, customization, quantity, unit price, total)
    - Payment (provider, amount, status, Stripe ID)
    - Shipping (full address, carrier, tracking)

#### Changing the status

- **"Marquer comme..."** (Mark as...) button:
    - **Processing** - order taken in charge (preparation)
    - **Shipped** - shipped → automatic email to the customer with tracking number
    - **Delivered** - delivered → automatic email
    - **Canceled** - canceled → automatic email

Emails are only sent **once** per transition, thanks to markers like `shipped_email_sent_at`, etc.

#### Entering a tracking number

- On the detail page, the **"Livraison"** (Shipping) panel → tracking field + carrier URL.
- Visible to the customer under **"Mes commandes"** (My orders).

---

## Part C - User Accounts

### Roles

| Role                  | Capabilities                                              |
|-----------------------|-----------------------------------------------------------|
| Anonymous             | Browse the catalog, contact support, add to cart          |
| Customer (`customer`) | + Add to cart, order, customize, view their orders        |
| Admin (`admin`)       | + Access the back-office, manage catalog / stock / orders |

The admin role is assigned via the artisan command:

```bash
php artisan tinker
>>> User::find(1)->roles()->attach(Role::where('name', 'admin')->first());
```

### Password reset

Not yet exposed in the UI - go through the admin to generate a new password:

```bash
php artisan tinker
>>> User::find($id)->update(['password' => Hash::make('new-password')]);
```

Planned evolution: standard self-service flow with a magic link via email.

---

## Part D - Troubleshooting

### "My cart disappears every time I log out"

This is intentional: the cart is tied to the user in the database. On the next login, it's retrieved as-is. If
empty, check whether the order was completed in the meantime (a successful payment empties the cart).

### "Payment fails"

- Check that the card isn't in test mode (4242 only works in a dev environment).
- 3D-Secure may be triggered by the bank - complete the process in the pop-up.
- If the error persists, check the Stripe Dashboard (`payment_intent.payment_failed` log).

### "A product shows stock = 0 but I just added some"

Clear the browser cache or refresh. Stock is recalculated on the fly via SQL query (sum of lot `quantity`).

### "The 3D editor won't open"

- Check that the browser supports WebGL (testable at <https://get.webgl.org>).
- Disable script blockers (uBlock can block `react-konva`).
