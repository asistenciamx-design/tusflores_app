const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";
const base = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1";

async function deleteTestOrders() {
  // First list all orders to see what's there
  const res = await fetch(`${base}/orders?select=id,folio,customer_name,product_name`, {
    headers: {
      "apikey": key,
      "Authorization": `Bearer ${key}`
    }
  });
  const orders = await res.json();
  console.log("All orders:", JSON.stringify(orders, null, 2));
  
  // Delete ALL existing orders (they are all test orders)
  if (orders.length > 0) {
    for (const order of orders) {
      const delRes = await fetch(`${base}/orders?id=eq.${order.id}`, {
        method: "DELETE",
        headers: {
          "apikey": key,
          "Authorization": `Bearer ${key}`
        }
      });
      console.log(`Deleted order ${order.id} (${order.folio}): ${delRes.status}`);
    }
  }
  
  // Verify
  const verifyRes = await fetch(`${base}/orders?select=id`, {
    headers: { "apikey": key, "Authorization": `Bearer ${key}` }
  });
  const remaining = await verifyRes.json();
  console.log("Remaining orders:", remaining.length);
}

deleteTestOrders();
