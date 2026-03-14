const url = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders";
const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";
const SHOP_ID = "5fe1a711-e184-4030-8b3e-20756a161c09";

// 5 productos reales de la tienda, 1 pedido por producto
const orders = [
  {
    folio: "#0045",
    product_name: "orquidea phalaenopsis fucsia",
    price: 1000.00,
    buyer_name: "Ana Garcia",
    buyer_whatsapp: "5512345678",
    buyer_email: "ana.garcia@gmail.com",
    recipient_name: "Maria Lopez",
    recipient_phone: "5598765432",
    dedication_message: "Feliz cumpleanos, te quiero mucho!",
    delivery_address: "Av. Insurgentes Sur 1234, Col. Del Valle",
    delivery_state: "Ciudad de Mexico",
    delivery_city: "CDMX",
    status: "pending",
    is_paid: false,
    shipping_cost: 80,
    days_ago: 0,
  },
  {
    folio: "#0046",
    product_name: "flores mariposa keramos",
    price: 2000.00,
    buyer_name: "Carlos Mendoza",
    buyer_whatsapp: "5587654321",
    buyer_email: "carlos.m@hotmail.com",
    recipient_name: "Lucia Mendoza",
    recipient_phone: "5511223344",
    dedication_message: "Con amor, para ti en este dia especial",
    delivery_address: "Calle Reforma 567, Col. Polanco",
    delivery_state: "Ciudad de Mexico",
    delivery_city: "CDMX",
    status: "pending",
    is_paid: true,
    payment_method: "Transferencia",
    shipping_cost: 120,
    days_ago: 1,
  },
  {
    folio: "#0047",
    product_name: "tulipanes morados y blancos",
    price: 1000.00,
    buyer_name: "Sofia Ramirez",
    buyer_whatsapp: "5544332211",
    buyer_email: "sofia.r@outlook.com",
    recipient_name: "Elena Vargas",
    recipient_phone: "5566778899",
    dedication_message: "Muchas felicidades en tu dia",
    delivery_address: "Blvd. Miguel de Cervantes Saavedra 301, Granada",
    delivery_state: "Ciudad de Mexico",
    delivery_city: "CDMX",
    status: "delivered",
    is_paid: true,
    payment_method: "Efectivo",
    shipping_cost: 80,
    days_ago: 3,
  },
  {
    folio: "#0048",
    product_name: "ranuculos y rosas",
    price: 1000.00,
    buyer_name: "Roberto Torres",
    buyer_whatsapp: "5500112233",
    buyer_email: "roberto.torres@gmail.com",
    recipient_name: "Patricia Torres",
    recipient_phone: "5533445566",
    dedication_message: "Para la mujer mas hermosa del mundo",
    delivery_address: "Av. Patriotismo 229, Col. San Pedro de los Pinos",
    delivery_state: "Ciudad de Mexico",
    delivery_city: "CDMX",
    status: "pending",
    is_paid: false,
    shipping_cost: 100,
    days_ago: 5,
  },
  {
    folio: "#0049",
    product_name: "florero",
    price: 1000.00,
    buyer_name: "Valentina Cruz",
    buyer_whatsapp: "5577889900",
    buyer_email: "vale.cruz@yahoo.com",
    recipient_name: "Gabriela Rios",
    recipient_phone: "5522334455",
    dedication_message: "Siempre en mi corazon",
    delivery_address: "Av. Universidad 1200, Col. Xoco",
    delivery_state: "Ciudad de Mexico",
    delivery_city: "CDMX",
    status: "pending",
    is_paid: true,
    payment_method: "Tarjeta",
    shipping_cost: 80,
    days_ago: 7,
  },
];

async function insertOrder(order) {
  const createdAt = new Date();
  createdAt.setDate(createdAt.getDate() - order.days_ago);

  const body = {
    shop_id: SHOP_ID,
    florist_id: SHOP_ID,
    folio: order.folio,
    product_name: order.product_name,
    customer_name: order.buyer_name,
    customer_phone: order.buyer_whatsapp,
    quantity: 1,
    price: order.price,
    total_price: order.price + order.shipping_cost,
    status: order.status,
    is_paid: order.is_paid,
    payment_method: order.payment_method || null,
    created_at: createdAt.toISOString(),
    sale_date: createdAt.toISOString(),
    delivery_info: "Envio a domicilio",
    delivery_method: "Envio a domicilio",
    shipping_cost: order.shipping_cost,
    is_anonymous: false,
    recipient_name: order.recipient_name,
    recipient_phone: order.recipient_phone,
    dedication_message: order.dedication_message,
    delivery_address: order.delivery_address,
    delivery_state: order.delivery_state,
    delivery_city: order.delivery_city,
    // buyer_* columnas pendientes de migracion (add_buyer_fields_to_orders.sql)
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "apikey": key,
      "Authorization": `Bearer ${key}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation",
    },
    body: JSON.stringify(body),
  });

  const text = await res.text();
  if (res.ok) {
    const data = JSON.parse(text);
    console.log(`✓ ${order.folio} - ${order.product_name} (comprador: ${order.buyer_name}) → ID: ${data[0]?.id}`);
  } else {
    console.error(`✗ ${order.folio} - Error ${res.status}: ${text}`);
  }
}

async function main() {
  console.log("Insertando 5 pedidos de prueba...\n");
  for (const order of orders) {
    await insertOrder(order);
  }
  console.log("\nListo.");
}

main();
