# Vendedores API (Laravel + MySQL)

## Requisitos
- XAMPP (Apache + MySQL)
- PHP 8.2+
- Composer

## Base de datos
1. Crear DB en MySQL: `perfumes_vendedores`
2. Archivo `.env` ya configurado para:
   - `DB_CONNECTION=mysql`
   - `DB_HOST=127.0.0.1`
   - `DB_PORT=3306`
   - `DB_DATABASE=perfumes_vendedores`
   - `DB_USERNAME=root`
   - `DB_PASSWORD=`

## Arranque
```bash
cd C:\xampp\htdocs\Perfumes\vendedores_api
php artisan config:clear
php artisan migrate --seed
php artisan serve --host=0.0.0.0 --port=8000
```

## Endpoints
- `POST /api/admin/entregas`
- `GET /api/admin/entregas/{id}`
- `POST /api/vendedor/login`
  - body: `{ "vendedor_id": 1, "pin": "1234" }`
- `GET /api/vendedor/{id}/pendientes`
- `POST /api/vendedor/entregas/{entregaId}/confirmar`
- `GET /api/vendedor/{id}/stock`

## Ejecutar app de vendedores
```bash
cd C:\xampp\htdocs\Perfumes\vendedores_api\vendedores_app
flutter pub get

# Emulador Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# Telefono fisico (usa IP LAN de tu PC)
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api
```

## Datos demo
Seeder crea:
- Vendedor demo: `id=1`, `pin=1234`
- Entregas: una pendiente_confirmacion y una confirmada
