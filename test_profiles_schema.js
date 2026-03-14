const key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx0YWFvZ3dwanBrdXdkY2ljZmV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMzYyMTQsImV4cCI6MjA4NzkxMjIxNH0.U0ECrwYg2GffEmP9JCX6_-oQgGawvT97NqRcxJT5s_k";
const url = `https://ltaaogwpjpkuwdcicfeu.supabase.co/rest/v1/?apikey=${key}`;

async function check() {
  const res = await fetch(url);
  const json = await res.json();
  const cols = Object.keys(json.definitions.profiles.properties);
  console.log("Profiles columns:", cols);
}

check();
