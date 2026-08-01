# Perfumes App - Flutter

Aplicación móvil para control completo del negocio de perfumes.

## Funcionalidades

- **Perfumes**: Inventario completo con stock, precio costo y precio venta
- **Vendedores**: Gestión de vendedores externos
- **Clientes**: Base de datos de clientes
- **Entregas a vendedores**: Control de perfumes entregados a cada vendedor para vender, con estado pendiente/pagado
- **Ventas a crédito**: Registro de ventas con múltiples productos, seguimiento de pagos parciales y saldo pendiente

## Requisitos

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

## Instalación

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en Android/iOS
flutter run

# Ejecutar app colega (solo perfumes, entregas y pedidos)
flutter run -t lib/main_colega.dart

# Compilar APK
flutter build apk --release
```

## Dependencias principales

| Paquete | Uso |
|---|---|
| `sqflite` | Base de datos SQLite local |
| `path` | Manejo de rutas de archivos |
| `intl` | Formateo de fechas |
| `provider` | Gestión de estado |

## Estructura del proyecto

```
lib/
  main.dart                    # Punto de entrada
  models/                      # Modelos de datos
    perfume.dart
    vendedor.dart
    cliente.dart
    entrega_vendedor.dart
    venta_credito.dart
    detalle_venta.dart
    pago_venta.dart
  database/
    database_helper.dart       # SQLite helper (singleton)
  screens/
    home_screen.dart           # Dashboard
    perfumes/                  # Pantallas de perfumes
    vendedores/                # Pantallas de vendedores
    clientes/                  # Pantallas de clientes
    entregas/                  # Entregas a vendedores
    ventas/                    # Ventas a crédito + detalle + pagos
  widgets/
    app_drawer.dart            # Menú lateral de navegación
```
