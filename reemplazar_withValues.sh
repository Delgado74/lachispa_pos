#!/bin/bash

echo "📦 Haciendo copia de respaldo de la carpeta 'lib'..."
cp -r lib lib_backup

echo "🔍 Buscando usos de 'withValues(alpha: ...)'..."
grep -rn '\.withValues(alpha:' lib

echo "🔁 Reemplazando por '.withOpacity(...)' en todos los .dart..."
find lib -name "*.dart" -type f -exec sed -i 's/\.withValues(alpha: \([^)]*\))/\.withOpacity(\1)/g' {} +

echo "✅ Reemplazo completado. La copia de respaldo está en 'lib_backup'."
