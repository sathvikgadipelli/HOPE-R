
#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for APP in civilian_app government_app; do
 cd "$ROOT/$APP"
 [ -d android ] || flutter create --no-pub --platforms=android,windows .
 flutter pub get
done
