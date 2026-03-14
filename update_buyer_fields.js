const BASE = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders";
const KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";

const updates = [
  { id: "8055b5bb-a0a4-4f58-9b1b-cfeb2fd3c44a", buyer_name: "Ana Garcia",      buyer_whatsapp: "5512345678", buyer_email: "ana.garcia@gmail.com"     },
  { id: "1b944c35-e4c7-4df3-b943-a61c5fe38bec", buyer_name: "Carlos Mendoza",  buyer_whatsapp: "5587654321", buyer_email: "carlos.m@hotmail.com"      },
  { id: "bd5fce3f-c6c5-4207-98b9-6bf4fa7c5867", buyer_name: "Sofia Ramirez",   buyer_whatsapp: "5544332211", buyer_email: "sofia.r@outlook.com"       },
  { id: "68d3166f-0323-4bf5-91eb-959536d48d63", buyer_name: "Roberto Torres",  buyer_whatsapp: "5500112233", buyer_email: "roberto.torres@gmail.com"  },
  { id: "520d098c-bd47-4736-953f-ea190f3e03c5", buyer_name: "Valentina Cruz",  buyer_whatsapp: "5577889900", buyer_email: "vale.cruz@yahoo.com"       },
];

async function main() {
  console.log("Actualizando buyer_* en los 5 pedidos de prueba...\n");
  for (const { id, buyer_name, buyer_whatsapp, buyer_email } of updates) {
    const res = await fetch(`${BASE}?id=eq.${id}`, {
      method: "PATCH",
      headers: {
        "apikey": KEY,
        "Authorization": `Bearer ${KEY}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
      },
      body: JSON.stringify({ buyer_name, buyer_whatsapp, buyer_email }),
    });
    const text = await res.text();
    if (res.ok) {
      console.log(`OK  ${buyer_name} (${buyer_whatsapp}) → ${buyer_email}`);
    } else {
      console.error(`ERR ${buyer_name}: ${text}`);
    }
  }
  console.log("\nListo.");
}

main();
