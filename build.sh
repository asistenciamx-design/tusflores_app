#!/bin/bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Get dependencies and build web app
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Renombrar index.html → app.html para que Vercel no lo sirva automáticamente en /
# Esto permite que el rewrite "/" → landing.html funcione correctamente
mv build/web/index.html build/web/app.html

# Actualizar flutter_bootstrap.js y flutter_service_worker.js para que apunten a app.html
sed -i 's|"index.html"|"app.html"|g' build/web/app.html
sed -i 's|index.html|app.html|g' build/web/flutter_service_worker.js 2>/dev/null || true

# Copy landing page static files into the build output
cp web/landing.html build/web/landing.html
cp web/galeria.html build/web/galeria.html
cp web/mockup-a.html build/web/mockup-a.html
cp -r web/landing_assets build/web/landing_assets
