const url = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders";
const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";

async function check() {
  const orderData = {
    "shop_id": "00000000-0000-0000-0000-000000000000",
    "florist_id": "00000000-0000-0000-0000-000000000000",
    "folio": "#1234",
    "product_name": "Test",
    "customer_name": "Test",
    "customer_phone": "123",
    "quantity": 1,
    "price": 100,
    "total_price": 100,
    "status": "pending",
    "created_at": new Date().toISOString(),
    "sale_date": new Date().toISOString(),
    "delivery_info": "Test",
    "is_paid": false,
    "payment_method": null,
    "shipping_cost": 0,
    "delivery_method": "Envío a domicilio",
    "is_anonymous": false,
    "recipient_name": "Test",
    "recipient_phone": "123",
    "dedication_message": "Test",
    "delivery_address": "Test",
    "delivery_references": "Test",
    "delivery_location_type": "Test",
    "delivery_state": "Test",
    "delivery_city": "Test"
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "apikey": key,
      "Authorization": `Bearer ${key}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    },
    body: JSON.stringify(orderData)
  });

  const text = await res.text();
  console.log("Status:", res.status);
  console.log("Response:", text);
}

check();
