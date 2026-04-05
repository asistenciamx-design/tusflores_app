#!/bin/bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Get dependencies and build web app
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Copy landing page static files into the build output
cp web/landing.html build/web/landing.html
cp web/galeria.html build/web/galeria.html
cp web/mockup-a.html build/web/mockup-a.html
cp -r web/landing_assets build/web/landing_assets
