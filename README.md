# Mi Alacena

Aplicación móvil desarrollada con **Flutter** para administrar el inventario doméstico de una alacena. Permite registrar artículos y sus lotes, controlar las fechas de caducidad, gestionar existencias, mantener un historial de compras por tienda y elaborar una lista de compras.


## Contenido

- [Objetivo](#objetivo)
- [Funcionalidades](#funcionalidades)
- [Tecnologías y dependencias](#tecnologías-y-dependencias)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Modelo de datos](#modelo-de-datos)
- [Reglas de negocio](#reglas-de-negocio)

## Objetivo

Diseñar e implementar una aplicación móvil que facilite el control de existencias domésticas y reduzca el desperdicio de productos por caducidad. La aplicación distingue entre el producto (por ejemplo, leche) y sus lotes, ya que un mismo producto puede adquirirse varias veces, en tiendas distintas y con diferentes fechas de caducidad.

## Funcionalidades

### Inventario de artículos

- Consulta de productos con imagen, categoría, marca, unidad, existencias y estado.
- Alta, edición y archivo de productos.
- Búsqueda de artículos y visualización de alertas.
- Las fotografías seleccionadas se copian al almacenamiento privado de la aplicación; la base de datos conserva la ruta local.
- Un producto puede tener varios lotes con sus propias cantidades y fechas.

### Estados y alertas

Los artículos utilizan colores e iconos para identificar rápidamente estos estados:

- **Caducado:** existe cantidad en uno o más lotes cuya fecha ya pasó.
- **Sin existencia:** el stock registrado es cero.
- **Por caducar:** la fecha de caducidad más próxima está dentro del periodo de alerta configurado.
- **Por agotarse:** el stock positivo es igual o menor al mínimo configurado.
- **Disponible:** no se cumple ninguna de las condiciones anteriores.

Cuando hay más de una condición, se muestra el estado más urgente de acuerdo con la prioridad implementada en `lib/components/app_utils.dart`.

### Lotes, compras y consumo FEFO

- Registro de cantidad, costo unitario, fecha de compra, fecha de caducidad y tienda de cada lote.
- Un nuevo lote registra el movimiento correspondiente en el historial de compras.
- El producto conserva la última tienda en la que se registró una compra.
- La ficha del producto permite consultar las tiendas y el historial de compras relacionados.
- El consumo descuenta primero las existencias vigentes del lote cuya fecha de caducidad sea más próxima (**FEFO: First Expired, First Out**).
- La operación de consumo se ejecuta dentro de una transacción SQLite para evitar que una operación incompleta deje cantidades parcialmente actualizadas.
- Las operaciones de compra y consumo se registran en tablas de historial separadas.

### Calendario y notificaciones locales

- El calendario utiliza `table_calendar`.
- Cada punto representa un producto distinto que tiene una alerta en la fecha mostrada; varios lotes del mismo producto que caducan el mismo día no duplican el marcador del producto.
- Al seleccionar un día, se abre una vista modal de pantalla completa con los artículos y datos relevantes.
- Los lotes programan notificaciones locales para las **09:00** del día de caducidad, utilizando la zona horaria `America/Mexico_City`.
- Al tocar una notificación, la aplicación intenta abrir el calendario en la fecha correspondiente.
- La aplicación solicita permiso para mostrar notificaciones en las versiones de Android que lo requieren.

Android puede retrasar las alarmas inexactas por decisiones de ahorro de batería. Las notificaciones también dependen de los permisos y de la configuración del sistema.

### Carrito de compras

- Desde el inventario se puede agregar un artículo al carrito.
- El icono del carrito utiliza `badges` para mostrar la cantidad de productos distintos incluidos.
- La cantidad deseada de cada artículo se puede ajustar desde la pantalla del carrito.
- El contenido del carrito se conserva en SQLite entre ejecuciones de la aplicación.

### Catálogos y estadísticas

- CRUD de categorías y tiendas.
- Las restricciones de integridad referencial impiden eliminar categorías o tiendas que sigan siendo utilizadas por registros relacionados.
- Pantalla de estadísticas con gasto histórico agrupado por tienda.
- Se utiliza `fl_chart` para representar datos mediante gráficas.

### Widgets considerados en la práctica

- `CustomScrollView`, `SliverAppBar` y `SliverList` para estructurar listas con slivers.
- `flutter_slidable` para mostrar acciones sobre las tarjetas mediante deslizamiento.
- `table_calendar` para el calendario y sus marcadores.
- `badges` para el contador del carrito.
- `fl_chart` para las gráficas de estadísticas.

## Tecnologías y dependencias

| Tecnología / paquete | Uso |
|---|---|
| Flutter / Dart | Interfaz y lógica de la aplicación móvil. |
| `sqflite` 2.4.1 | Persistencia SQLite local. |
| `path` ^1.9.1 | Operaciones con rutas de archivos. |
| `path_provider` 2.1.5 | Acceso a directorios privados de la aplicación. |
| `image_picker` 1.1.2 | Selección de imágenes desde la galería. |
| `table_calendar` 3.2.1 | Calendario y eventos por fecha. |
| `badges` 3.1.2 | Contador visual del carrito. |
| `flutter_slidable` 3.1.2 | Acciones por deslizamiento en listas. |
| `fl_chart` 0.70.2 | Gráficas de estadísticas. |
| `intl` ^0.20.3 | Formateo de fechas, idioma y moneda. |
| `flutter_local_notifications` 17.2.4 | Notificaciones locales programadas. |
| `timezone` 0.9.4 | Configuración de zona horaria para las alarmas. |
| `flutter_localizations` | Recursos de localización de Flutter. |

Las restricciones exactas están declaradas en `pubspec.yaml`. Conviene ejecutar `flutter pub get` en lugar de cambiar las versiones de los paquetes de manera indiscriminada, ya que algunas dependencias comparten restricciones de Dart y `intl`.

## Estructura del proyecto

```text
lib/
├── main.dart
├── components/
│   ├── app_navigator.dart
│   ├── app_utils.dart
│   └── product_card.dart
├── database/
│   └── inventory_db.dart
├── services/
│   └── notification_service.dart
└── screens/
    ├── inventory_screen.dart
    ├── product_form_screen.dart
    ├── product_detail_screen.dart
    ├── lot_form_screen.dart
    ├── calendar_screen.dart
    ├── cart_screen.dart
    ├── catalog_screen.dart
    └── stats_screen.dart
```

### Responsabilidad de cada carpeta

- **`screens/`:** pantallas, formularios y navegación de la interfaz.
- **`components/`:** widgets reutilizables, navegación y utilidades de presentación.
- **`database/`:** creación de la base SQLite, tablas, consultas, restricciones y operaciones CRUD. `InventoryDB` centraliza las operaciones persistentes.
- **`services/`:** inicialización, permisos, programación y atención de notificaciones locales.

La aplicación inicia en `InventoryScreen`. Las rutas nombradas están registradas en `lib/main.dart` y centralizan la navegación a las demás pantallas.

## Modelo de datos

La base se llama `alacena_local.db` y se crea en el directorio de bases de datos de la aplicación mediante `sqflite`. Al crearse por primera vez, se insertan categorías de ejemplo y dos tiendas iniciales.

| Tabla | Finalidad y campos relevantes |
|---|---|
| `categories` | Catálogo de categorías: `id`, `name`, `icon`. El nombre es obligatorio y único sin distinguir mayúsculas y minúsculas. |
| `stores` | Tiendas: `id`, `name`, `address`, `phone`. El nombre es obligatorio y único sin distinguir mayúsculas y minúsculas. |
| `products` | Datos del producto: nombre, marca, categoría, unidad, stock mínimo, días de alerta, ruta de imagen, última tienda y estado activo/archivado. |
| `lots` | Lotes: producto, cantidades inicial y actual, caducidad, compra, tienda, costo y estado de notificación. |
| `purchase_history` | Historial de compras: producto, tienda, lote relacionado, cantidad, costo y fecha. |
| `consumption_history` | Historial de consumo: producto, lote, cantidad consumida y fecha. |
| `cart` | Lista de compra local: producto y cantidad deseada. Hay como máximo una fila de carrito por producto. |

### Relaciones principales

```text
categories 1 ─── N products
stores     1 ─── N lots
products   1 ─── N lots
products   1 ─── N purchase_history
stores     1 ─── N purchase_history
products   1 ─── N consumption_history
products   1 ─── 0..1 cart
products.ultima_tienda_id ─── stores.id
```

Las claves foráneas se habilitan al abrir la base de datos con `PRAGMA foreign_keys = ON`. Se utilizan restricciones `CHECK` para evitar cantidades o costos negativos y para limitar algunos campos a valores válidos. Las categorías y tiendas con referencias activas no se pueden eliminar, protegiendo la integridad y la trazabilidad.

## Reglas de negocio

### Cálculo de existencias

El stock total de un producto se calcula sumando `quantity_current` de todos sus lotes con cantidad positiva. Esta cifra representa las unidades físicas registradas; las cantidades de lotes vencidos también forman parte del total físico, pero se identifican por separado en `expired_stock` y provocan el estado de mayor prioridad.

### FEFO

Al consumir una cantidad:

1. Se consultan los lotes del producto con cantidad positiva y fecha de caducidad igual o posterior al día actual.
2. Se ordenan por caducidad ascendente y, en caso de empate, por identificador de lote.
3. Se resta la cantidad solicitada empezando por el primer lote y se continúa con los siguientes si hace falta.
4. Se registra cada descuento en `consumption_history` dentro de la misma transacción.
5. Si las existencias vigentes no alcanzan, se cancela la operación y no se dejan descuentos parciales.

Los lotes vencidos no se consumen mediante esta operación.

### Trazabilidad de compras

Al registrar un lote nuevo, `InventoryDB.saveLot()` inserta el lote, crea el registro en `purchase_history` y actualiza `products.ultima_tienda_id` dentro de una transacción. Editar un lote existente modifica sus datos de existencias y caducidad, pero no reescribe la compra histórica original.

Los productos se archivan para conservar la trazabilidad. Si se elimina un lote, el historial de compra permanece y la referencia a ese lote pasa a `NULL`, según la restricción de la base de datos.

### Eventos del calendario

Las fechas de caducidad proceden de los lotes con existencias. Las alertas de productos agotados, por agotarse o con unidades vencidas se agrupan en el día actual, porque el sistema no puede deducir una fecha futura de agotamiento sin un modelo de consumo estimado.


## Uso básico de la aplicación

1. **Configurar catálogos:** entra a *Catálogos* para registrar categorías y tiendas. El primer inicio ya inserta algunos registros de ejemplo.
2. **Registrar producto:** abre *Nuevo artículo*, captura nombre, categoría, unidad, stock mínimo y días de anticipación; opcionalmente selecciona una imagen.
3. **Registrar existencias:** abre la ficha del producto y registra uno o más lotes. Cada lote requiere cantidad, costo unitario, fecha de compra, caducidad y tienda.
4. **Registrar múltiples compras:** para una nueva compra del mismo artículo, crea otro lote del producto existente en lugar de duplicar el producto.
5. **Consumir unidades:** desde la ficha del producto utiliza la opción de consumo e introduce una cantidad válida. FEFO distribuirá la cantidad entre los lotes vigentes en orden de caducidad.
6. **Consultar calendario:** entra a *Calendario*, revisa los marcadores y toca una fecha para ver los artículos que tienen eventos ese día.
7. **Armar lista de compra:** agrega artículos desde las tarjetas del inventario y revisa o ajusta las cantidades en *Carrito*.
8. **Consultar estadísticas:** abre *Estadísticas* para ver datos de existencias y el gasto por tienda. La opción de prueba permite comprobar las notificaciones locales.

## Referencias

- [Flutter](https://docs.flutter.dev/)
- [sqflite](https://pub.dev/packages/sqflite)
- [table_calendar](https://pub.dev/packages/table_calendar)
- [badges](https://pub.dev/packages/badges)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [image_picker](https://pub.dev/packages/image_picker)
- [flutter_slidable](https://pub.dev/packages/flutter_slidable)
- [fl_chart](https://pub.dev/packages/fl_chart)
