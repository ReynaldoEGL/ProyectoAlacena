# Mi Alacena — Flutter + SQLite local

Aplicación móvil para inventario doméstico. Está diseñada para ejecutarse en Android (emulador o teléfono) y almacenar la información localmente en SQLite. **No utiliza Firebase ni necesita conexión a Internet para sus operaciones de inventario.**

## 1. Qué incluye

- CRUD de artículos, categorías, tiendas y lotes.
- Imágenes de artículos copiadas al almacenamiento privado de la aplicación.
- Existencias calculadas sumando `quantity_current` de todos los lotes que tengan cantidad positiva.
- Estados visuales: Caducado, Sin existencia, Por caducar, Por agotarse y Disponible.
- Consumo FEFO dentro de una transacción SQLite; descuenta primero los lotes vigentes cuya caducidad es más próxima.
- Historial de compras por tienda y actualización transaccional de la última tienda de compra.
- Calendario con `table_calendar`; cada punto representa un producto distinto con alerta en esa fecha. Un día seleccionado abre una vista modal de pantalla completa.
- Carrito persistente con contador mediante `badges`.
- Notificaciones locales en la fecha de caducidad (09:00, zona `America/Mexico_City`); al tocar la notificación se abre el calendario en ese día.
- Estadísticas y gasto histórico por tienda con `fl_chart`.
- `CustomScrollView`, `SliverAppBar` y `SliverList` en las pantallas de listados.
- Acciones por deslizamiento en las tarjetas con `flutter_slidable`.

## 2. Estructura de archivos

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

La capa `database` contiene el esquema SQL y las operaciones de datos. Las reglas FEFO y trazabilidad no están en los widgets; se implementan en `InventoryDB`. `app_utils.dart` calcula el estado visual y centraliza el formato de fechas, cantidades e imágenes.

## 3. Antes de empezar en Windows

1. Instala Flutter estable siguiendo la [guía oficial de Flutter para Windows](https://docs.flutter.dev/get-started/install/windows/mobile).
2. Instala Android Studio. En **More Actions → SDK Manager**, instala Android SDK Platform 34 o superior y Android SDK Build-Tools. En **More Actions → Virtual Device Manager**, crea un dispositivo virtual Android.
3. Abre PowerShell y ejecuta:

   ```powershell
   flutter --version
   flutter doctor -v
   flutter devices
   ```

4. Si `flutter doctor` marca Android licenses, ejecuta `flutter doctor --android-licenses` y acepta las licencias. Vuelve a correr `flutter doctor -v`.

> Esta aplicación usa `sqflite`; para esta entrega pruébala en un emulador Android o teléfono Android. No la ejecutes como aplicación web en Chrome esperando que SQLite móvil funcione allí.

## 4. Crear el proyecto Flutter nativo

La carpeta de este paquete contiene el código Dart y el `pubspec.yaml`, pero los archivos generados de Android dependen de la versión de Flutter que tengas. Genera esos archivos con tu SDK y después copia el código entregado.

1. Descarga `alacena_local.zip` y localízalo en la carpeta Descargas. **No lo extraigas dentro de otra carpeta Flutter existente**.
2. Abre PowerShell y copia este bloque. Si descargaste el ZIP en otra carpeta, cambia únicamente la ruta de `-LiteralPath`:

   ```powershell
   cd "$HOME\Desktop\PracticasWeb"
   Expand-Archive -LiteralPath "$HOME\Downloads\alacena_local.zip" -DestinationPath ".\alacena_local_source" -Force
   flutter create --org com.emman --platforms=android alacena_local
   Copy-Item -Path .\alacena_local_source\lib\* -Destination .\alacena_local\lib -Recurse -Force
   Copy-Item -Force .\alacena_local_source\pubspec.yaml .\alacena_local\pubspec.yaml
   Copy-Item -Force .\alacena_local_source\README.md .\alacena_local\README.md
   ```

   `alacena_local_source` contiene el código entregado; `alacena_local` es el proyecto nativo generado por Flutter. Esta separación evita que `flutter create` sobrescriba el código fuente del ZIP.
3. Entra al proyecto y resuelve las dependencias:

   ```powershell
   cd .\alacena_local
   flutter pub get
   ```

4. Abre la carpeta `alacena_local` con Visual Studio Code. En Explorer, confirma que existan `lib\main.dart`, `lib\database\inventory_db.dart` y `android\app\src\main\AndroidManifest.xml`.

### Error probable: `Version solving failed`

- Comprueba primero `flutter --version`; el `pubspec.yaml` pide Dart 3.5.4 o superior.
- No agregues otra versión de `intl`, `timezone` o `flutter_local_notifications` por encima de las indicadas sin revisar compatibilidad entre paquetes.
- Ejecuta `flutter pub get` desde la carpeta que contiene exactamente el `pubspec.yaml` de la aplicación.

## 5. Configurar las notificaciones Android

La app usa `flutter_local_notifications` 17.2.4 para mantener compatibilidad con el rango de Dart indicado. En Android necesita configurar desugaring y los receptores que restauran alarmas tras un reinicio.

### 5.1 Gradle

1. En VS Code, abre `android/app/build.gradle.kts`.
2. Dentro del bloque `android { ... }`, localiza `compileOptions`. **No dupliques el bloque si ya existe**; añade `isCoreLibraryDesugaringEnabled = true` y confirma compatibilidad Java 17:

   ```kotlin
   compileOptions {
       isCoreLibraryDesugaringEnabled = true
       sourceCompatibility = JavaVersion.VERSION_17
       targetCompatibility = JavaVersion.VERSION_17
   }
   ```

3. En ese mismo archivo, dentro de `android { ... }`, comprueba que `compileSdk` sea al menos 34. En una plantilla reciente puedes dejar `compileSdk = flutter.compileSdkVersion` si el valor resuelto es 34 o superior. Si está por debajo, instala una plataforma más nueva desde Android Studio y ajusta `compileSdk` a una que sí esté instalada.
4. Dentro del bloque `dependencies { ... }` del mismo archivo agrega:

   ```kotlin
   coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   ```

5. Si el archivo tiene `kotlinOptions`, conserva o ajusta el objetivo a Java 17:

   ```kotlin
   kotlinOptions {
       jvmTarget = JavaVersion.VERSION_17.toString()
   }
   ```

**Importante:** si el archivo se llama `build.gradle` (sin `.kts`), la plantilla usa Groovy y no Kotlin DSL; no pegues sintaxis Kotlin en ese archivo. Conserva la estructura que haya generado tu instalación de Flutter.

### 5.2 Manifest

1. Abre `android/app/src/main/AndroidManifest.xml`.
2. Entre `<manifest ...>` y `<application ...>`, agrega:

   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   <uses-permission android:name="android.permission.VIBRATE" />
   ```

3. Dentro de `<application ...> ... </application>`, agrega estos dos receptores, cuidando que queden al mismo nivel que `<activity>`, no dentro de ella:

   ```xml
   <receiver
       android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />

   <receiver
       android:exported="false"
       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
       <intent-filter>
           <action android:name="android.intent.action.BOOT_COMPLETED" />
           <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
           <action android:name="android.intent.action.QUICKBOOT_POWERON" />
           <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
       </intent-filter>
   </receiver>
   ```

La app utiliza alarmas **inexactas** para no requerir permiso de alarmas exactas. `POST_NOTIFICATIONS` declara el permiso de notificaciones en Android 13 o posterior; al primer uso, pulsa **Permitir** cuando aparezca el cuadro del sistema.

### Error probable: `coreLibraryDesugaring` o `compileSdk`

- Revisa que agregaste la dependencia dentro de `dependencies` en `android/app/build.gradle.kts`, no en el archivo Gradle raíz.
- Revisa que exista un solo bloque `compileOptions`.
- Instala la versión de Android SDK que uses como `compileSdk` en Android Studio → SDK Manager.
- Conserva los archivos `settings.gradle(.kts)` y las versiones de Gradle generadas por Flutter; no pegues un ejemplo de otra versión de plantilla sin comparar.

## 6. Ejecutar la aplicación

1. En Android Studio, abre **Device Manager / Virtual Device Manager** y pulsa ▶ para iniciar el emulador. También puedes conectar el teléfono por USB con las opciones de desarrollador y depuración USB habilitadas.
2. En PowerShell, dentro del proyecto, ejecuta:

   ```powershell
   flutter clean
   flutter pub get
   flutter analyze
   flutter devices
   flutter run
   ```

3. Si aparecen varios dispositivos, utiliza el identificador que muestre `flutter devices`:

   ```powershell
   flutter run -d <ID_DEL_DISPOSITIVO>
   ```

4. Para generar un APK instalable:

   ```powershell
   flutter build apk --release
   ```

   El archivo se genera en `build\app\outputs\flutter-apk\app-release.apk`.

## 7. Primera configuración dentro de la aplicación

La base local inicia con categorías de ejemplo y dos tiendas editables: `Supermercado` y `Mercado local`.

1. En la pantalla **Mi Alacena**, pulsa **Catálogos** para agregar, renombrar o eliminar categorías y tiendas.
2. Pulsa **Nuevo artículo**. Captura nombre, categoría, unidad, stock mínimo y días de anticipación. Pulsa el icono de fotografía para elegir una imagen de la galería.
3. Guarda el artículo. Se mostrará inicialmente sin existencia porque todavía no tiene lotes.
4. Toca la tarjeta del artículo y pulsa **Registrar lote**. Captura cantidad, costo por unidad, fecha de compra, fecha de caducidad y tienda.
5. Repite el paso anterior para registrar otro lote del mismo artículo, con otra fecha de caducidad o tienda. **No crees un producto duplicado solo para representar dos compras**; crea dos lotes del mismo producto.
6. En la ficha del artículo consulta los lotes, el historial de compras y todas las tiendas en las que se adquirió.
7. En **Calendario**, los puntos se agrupan por producto y fecha; al tocar el día se abre la lista de pantalla completa.
8. En las tarjetas del inventario, toca el icono del carrito para crear la lista de compra. El contador del carrito muestra la cantidad de productos distintos; dentro del carrito puedes ajustar las cantidades.
9. En **Estadísticas**, revisa las alertas, el gasto por tienda y usa **Probar notificación local** para comprobar rápidamente el permiso de notificaciones.

## 8. Casos de prueba para validar la práctica

### Caso A: Integridad referencial

1. Intenta eliminar una categoría utilizada por un producto: debe bloquearse y mostrar un mensaje.
2. Intenta eliminar una tienda que esté asociada a un lote o compra: debe bloquearse para conservar la trazabilidad.
3. Comprueba que no se permite guardar cantidad o costo negativo.

### Caso B: FEFO

1. Crea el producto `Leche prueba` con unidad `pieza`.
2. Registra lote A: cantidad 3, caducidad dentro de 3 días.
3. Registra lote B: cantidad 5, caducidad dentro de 10 días.
4. En la ficha del producto, consume 4 unidades.
5. Resultado esperado: lote A queda en 0 y lote B queda en 4. El consumo se registra usando primero el lote con caducidad más cercana. Los lotes vencidos se excluyen del consumo para evitar registrar como consumibles productos vencidos.

### Caso C: estados

- Producto sin lotes: `Sin existencia`.
- Lote con cantidad positiva y caducidad anterior a hoy: `Caducado`.
- Lote con caducidad dentro del umbral configurado: `Por caducar`.
- Stock total positivo igual o inferior al mínimo: `Por agotarse`.
- Existencia suficiente y sin lote vencido ni caducidad próxima: `Disponible`.

### Caso D: calendario y alarmas

1. Registra lotes de dos productos distintos con la misma fecha futura de caducidad.
2. En esa fecha del calendario deben aparecer dos puntos (uno por producto).
3. Toca el día y confirma que el modal ocupa la pantalla completa y muestra producto, imagen, categoría, cantidad y fecha.
4. Pulsa **Probar notificación local** en Estadísticas y confirma que aparece en el panel de Android.
5. Para probar una alarma programada, registra un lote con fecha futura, mantén la app cerrada y comprueba el día de caducidad. La alarma está programada para las 09:00 locales; Android puede retrasar alarmas inexactas debido a ahorro de batería.

## 9. Decisiones importantes de diseño

- **SQLite es la persistencia local principal.** Los datos no se suben a Firebase ni a un servidor. La información vive en el almacenamiento privado de la aplicación.
- **Imágenes:** el selector entrega una ruta temporal, por eso `ProductFormScreen` copia la fotografía a la carpeta privada de documentos de la app y guarda esa ruta en SQLite.
- **Stock total:** se suma `quantity_current` de los lotes con cantidad positiva, incluyendo los que estén vencidos, para reflejar la cantidad física registrada. Los lotes vencidos generan una alerta prioritaria y no se consumen por FEFO.
- **FEFO:** solo se consumen lotes no vencidos, ordenados por caducidad ascendente, dentro de una transacción.
- **Última tienda:** cada lote de compra nuevo inserta `purchase_history` y actualiza `products.ultima_tienda_id` en una transacción. Editar un lote no altera la compra histórica.
- **Historial:** compras y consumos son registros de trazabilidad. Al eliminar un lote, la compra histórica se conserva y su `lot_id` se vuelve nulo.
- **Productos:** se archivan en lugar de borrarse físicamente para no romper el historial de compras.
- **Calendario:** caducidades se muestran en la fecha de los lotes; alertas de stock bajo o agotado se anotan en el día actual porque la base no puede inferir en qué fecha se agotará un producto sin datos de consumo estimado.
- **Notificaciones:** el aviso se programa para las 09:00 del día de caducidad. La zona horaria está definida como `America/Mexico_City` en `lib/services/notification_service.dart`; cámbiala si el dispositivo y la práctica requieren otra zona.

## 10. Errores comunes

| Mensaje / problema | Qué revisar |
|---|---|
| `No devices found` | Inicia un emulador en Android Studio o conecta el teléfono con depuración USB. Después ejecuta `flutter devices`. |
| El calendario sale en inglés | Comprueba `initializeDateFormatting('es_MX', null)` en `main.dart` y `locale: 'es_MX'` en `TableCalendar`. |
| No hay imagen | Revisa que el archivo exista en la ruta guardada; vuelve a elegir la imagen si fue eliminada por el sistema. La app usa una imagen de reemplazo si la ruta no existe. |
| No sale una notificación | Da permiso en Android; revisa notificaciones del sistema, ahorro de batería y que la fecha de caducidad no esté en el pasado. Android puede retrasar alarmas inexactas. |
| Se duplica el producto en el carrito | El carrito tiene una fila por producto; cada pulsación aumenta la cantidad de ese mismo producto en lugar de duplicar la fila. |
| No se puede borrar tienda/categoría | Es el comportamiento esperado cuando existen referencias; primero reasigna o conserva la tienda/categoría para no dañar la trazabilidad. |
| La gráfica no tiene barras | Registra al menos una compra con costo por unidad mayor que cero. |
| Los datos desaparecen tras reinstalar | SQLite y las imágenes son locales al dispositivo; desinstalar la app elimina su almacenamiento privado. No es sincronización en la nube. |

## 11. Publicar el repositorio en GitHub

1. En GitHub, pulsa **New repository** y crea `alacena-local` (sin inicializar README si ya usarás el de este proyecto).
2. En PowerShell, dentro de la raíz Flutter:

   ```powershell
   git init
   git add .
   git commit -m "Implementa inventario local de alacena"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/alacena-local.git
   git push -u origin main
   ```

3. Sustituye `TU_USUARIO` por tu usuario real. No subas credenciales personales; en este proyecto no se requieren claves Firebase.
4. Para la entrega, verifica que el README esté visible en GitHub y comparte el enlace del repositorio.

## Referencias de paquetes

- [sqflite](https://pub.dev/packages/sqflite)
- [table_calendar](https://pub.dev/packages/table_calendar)
- [badges](https://pub.dev/packages/badges)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [image_picker](https://pub.dev/packages/image_picker)
- [flutter_slidable](https://pub.dev/packages/flutter_slidable)
- [fl_chart](https://pub.dev/packages/fl_chart)
