const url = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";

async function check() {
  const urlParams = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders";
  // The 'anon' key should only be able to insert if RLS allows it.
  // We'll insert a real order with a real shop id from the profile table to test RLS.
  
  // 1. Get a valid shop id
  const profileRes = await fetch("https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/profiles?select=id&limit=1", {
    headers: {
      "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k",
      "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k"
    }
  });
  
  const profiles = await profileRes.json();
  const shopId = profiles[0].id;
  console.log("Using shop id:", shopId);

  const orderData = {
    "shop_id": shopId,
    "florist_id": shopId,
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

  const res = await fetch("https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders", {
    method: "POST",
    headers: {
      "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k",
      "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k",
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
