const url = "https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/orders?limit=1";
const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";

async function check() {
  const res = await fetch(url, {
    method: "GET",
    headers: {
      "apikey": key,
      "Authorization": `Bearer ${key}`
    }
  });

  const text = await res.text();
  console.log("Status:", res.status);
  console.log("Response:", text);
}

check();
