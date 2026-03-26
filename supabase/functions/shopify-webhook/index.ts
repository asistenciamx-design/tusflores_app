// ─────────────────────────────────────────────────────────────────────────────
// Edge Function: shopify-webhook
// Recibe el webhook orders/create de Shopify, verifica HMAC,
// mapea los campos y los inserta en la tabla orders de Supabase.
// ─────────────────────────────────────────────────────────────────────────────

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ── Verificación HMAC-SHA256 (seguridad: confirma que viene de Shopify) ───────
async function verifyShopifyHmac(
  body: string,
  hmacHeader: string,
  secret: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(body)
  );
  const computed = btoa(String.fromCharCode(...new Uint8Array(signature)));
  return computed === hmacHeader;
}

// ── Extrae un valor de note_attributes por nombre ─────────────────────────────
function getNoteAttr(
  attrs: Array<{ name: string; value: string }>,
  name: string
): string | null {
  return attrs?.find((a) => a.name === name)?.value ?? null;
}

// ── Extrae la dedicatoria de las propiedades del line_item ────────────────────
function getDedication(
  lineItems: Array<{ properties?: Array<{ name: string; value: string }> }>
): string | null {
  for (const item of lineItems ?? []) {
    for (const prop of item.properties ?? []) {
      if (prop.name.toLowerCase().includes("dedicatoria")) {
        return prop.value;
      }
    }
  }
  return null;
}

// ── Convierte "25/03/2026" → "2026-03-25" (ISO) ──────────────────────────────
function parseMexDate(dateStr: string | null): string | null {
  if (!dateStr) return null;
  const parts = dateStr.split("/");
  if (parts.length !== 3) return null;
  const [day, month, year] = parts;
  return `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
}

// ── Mapea un pedido de Shopify al modelo de tusflores ─────────────────────────
function mapShopifyOrder(order: any, shopId: string): Record<string, unknown> {
  const noteAttrs: Array<{ name: string; value: string }> =
    order.note_attributes ?? [];
  const shipping = order.shipping_address ?? {};
  const customer = order.customer ?? {};
  const lineItems: any[] = order.line_items ?? [];

  // Nombre del comprador
  const buyerName =
    `${customer.first_name ?? ""} ${customer.last_name ?? ""}`.trim() ||
    order.email ||
    "Cliente Shopify";

  // Nombre del producto (todos los line items separados por coma)
  const productName =
    lineItems.map((i: any) => i.name).join(", ") || "Producto Shopify";

  // Fecha de entrega desde note_attributes
  const rawDeliveryDate = getNoteAttr(noteAttrs, "Fecha de entrega");
  const deliveryDate = parseMexDate(rawDeliveryDate);
  const deliveryTimeRange = getNoteAttr(noteAttrs, "Tiempo de entrega");

  // Folio: Shopify usa "Número:: 3063" → lo limpiamos
  const folio = (order.name ?? "").replace("Número::", "").trim();

  return {
    shop_id: shopId,
    florist_id: shopId,
    source: "shopify",
    shopify_order_id: String(order.id),
    folio: folio || `SH-${order.id}`,
    product_name: productName,

    // Comprador
    customer_name: buyerName,
    customer_phone: shipping.phone ?? customer.phone ?? "",
    buyer_name: buyerName,
    buyer_email: order.email ?? "",
    buyer_whatsapp: shipping.phone ?? customer.phone ?? "",

    // Destinatario
    recipient_name: shipping.name ?? "",
    recipient_phone: shipping.phone ?? "",

    // Entrega
    delivery_method: getNoteAttr(noteAttrs, "Order Type") === "Pickup"
      ? "Recolección en tienda"
      : "Envío a domicilio",
    delivery_address:
      [shipping.address1, shipping.address2].filter(Boolean).join(", "),
    delivery_city: shipping.city ?? "",
    delivery_state: shipping.province ?? "",
    delivery_date: deliveryDate,
    delivery_time_range: deliveryTimeRange,
    delivery_info: [
      deliveryDate,
      deliveryTimeRange,
      shipping.address1,
      shipping.city,
    ]
      .filter(Boolean)
      .join(" | "),

    // Dedicatoria
    dedication_message: getDedication(lineItems),

    // Pago
    price: parseFloat(order.current_subtotal_price ?? "0"),
    total_price: parseFloat(order.current_total_price ?? "0"),
    shipping_cost: parseFloat(
      order.total_shipping_price_set?.shop_money?.amount ?? "0"
    ),
    quantity: lineItems.reduce((sum: number, i: any) => sum + (i.quantity ?? 1), 0),
    is_paid: order.financial_status === "paid",
    payment_method: order.payment_gateway_names?.[0] ?? null,

    // Estado inicial
    status: "waiting",
    is_anonymous: false,
    created_at: order.created_at ?? new Date().toISOString(),
    sale_date: order.created_at ?? new Date().toISOString(),
    completion_photos: [],
  };
}

// ── Handler principal ─────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  console.log(`[webhook] ${req.method} recibido`);

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const shopDomain = req.headers.get("x-shopify-shop-domain") ?? "";
  const hmacHeader = req.headers.get("x-shopify-hmac-sha256") ?? "";
  const topic = req.headers.get("x-shopify-topic") ?? "";

  console.log(`[webhook] topic="${topic}" domain="${shopDomain}"`);

  // Aceptamos orders/create y webhooks de prueba
  if (!topic.includes("orders/create") && topic !== "") {
    console.log(`[webhook] topic ignorado: ${topic}`);
    return new Response("Ignored topic", { status: 200 });
  }

  const body = await req.text();
  console.log(`[webhook] body length=${body.length}`);

  // Conectamos a Supabase con service_role para leer shopify_connections
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Buscamos la conexión de esta tienda
  const { data: connection, error: connError } = await supabase
    .from("shopify_connections")
    .select("shop_id, client_secret")
    .eq("shopify_domain", shopDomain)
    .eq("is_active", true)
    .single();

  if (connError || !connection) {
    console.error(`[webhook] conexión no encontrada para dominio: "${shopDomain}"`);
    // En modo diagnóstico devolvemos 200 para ver el log
    return new Response("Shop not connected", { status: 200 });
  }

  console.log(`[webhook] conexión encontrada para shop_id: ${connection.shop_id}`);

  // Verificamos la firma HMAC (omitimos en webhooks de prueba sin HMAC)
  if (hmacHeader) {
    const isValid = await verifyShopifyHmac(body, hmacHeader, connection.client_secret);
    if (!isValid) {
      console.error("[webhook] HMAC inválido");
      return new Response("Invalid signature", { status: 401 });
    }
    console.log("[webhook] HMAC válido ✅");
  } else {
    console.log("[webhook] sin HMAC (modo prueba)");
  }

  let order: any;
  try {
    order = JSON.parse(body);
  } catch (e) {
    console.error("[webhook] body no es JSON válido");
    return new Response("Invalid JSON", { status: 400 });
  }

  const mappedOrder = mapShopifyOrder(order, connection.shop_id);
  console.log(`[webhook] mapeado: folio=${mappedOrder.folio}`);

  // Verificar si el pedido ya existe (evita duplicados)
  const { data: existing } = await supabase
    .from("orders")
    .select("id")
    .eq("shopify_order_id", String(order.id))
    .maybeSingle();

  if (existing) {
    console.log(`[webhook] pedido ya existe, ignorando: ${mappedOrder.folio}`);
    return new Response("Already exists", { status: 200 });
  }

  const { error: insertError } = await supabase
    .from("orders")
    .insert(mappedOrder);

  if (insertError) {
    console.error("[webhook] error al insertar:", insertError.message);
    return new Response("Insert error", { status: 500 });
  }

  console.log(`✅ Pedido Shopify importado: ${mappedOrder.folio} (${shopDomain})`);
  return new Response("OK", { status: 200 });
});
