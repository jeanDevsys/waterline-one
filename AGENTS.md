# AGENTS.md — Waterline One

## Proyecto
Waterline One es una plataforma web para una empresa distribuidora de agua. Su objetivo principal es hacer trazables y verificables las operaciones de campo: clientes, ubicaciones, entregas, créditos, pagos, liquidaciones, constancias y auditoría.

Lema del proyecto: **Cada entrega. Cada pago. Bajo control.**

## Fuente de verdad
Antes de implementar una funcionalidad, revisar primero:

1. `README.md`
2. `docs/01-contexto-y-problema.md`
3. `docs/02-requerimientos-preliminares.md`
4. `docs/03-flujo-de-cobros.md`
5. `docs/04-alcance-y-etapas.md`
6. `docs/05-presupuesto.md`
7. `docs/06-arquitectura.md`
8. `docs/07-backlog-inicial.md`
9. `docs/formales/` como documentación formal complementaria.

Si existe contradicción entre código y documentación de negocio, no inventar una regla nueva. Señalar la contradicción y conservar trazabilidad de la decisión.

## Arquitectura base del MVP
- Frontend: Angular + Angular Material.
- Backend/API: FastAPI + SQLAlchemy.
- Base de datos: MySQL 8.4 LTS (decisión solicitada por el usuario el 05/09/2026; ver `docs/08-decision-base-de-datos-mysql.md`).
- Mapas: Leaflet + OpenStreetMap.
- Analítica futura: Python + Pandas + scikit-learn.
- Constancias: PDF y/o impresión térmica Bluetooth.

Mantener frontend, backend, base de datos, ML, infraestructura y pruebas separados según la estructura existente del repositorio.

## Actores principales
### Propietario / Administrador
Puede supervisar clientes, créditos, pagos, efectivo pendiente, liquidaciones, reportes, auditoría y anulaciones autorizadas.

### Vendedor
Usa el sistema en campo. Debe poder localizar clientes, registrar entregas, créditos, pagos o abonos y generar constancias con pocos pasos.

### Cliente
No necesita instalar una aplicación. Conserva una constancia impresa o consulta una constancia de solo lectura mediante folio, código corto o QR cuando esté disponible.

## Reglas de negocio no negociables
1. Cada operación confirmada debe conservar fecha, usuario responsable y folio único.
2. Los movimientos confirmados no se eliminan físicamente ni se reescriben como si nunca hubieran existido.
3. Un pago incorrecto se anula mediante una operación controlada por administrador, con motivo y evidencia en auditoría.
4. El saldo del cliente debe derivarse de operaciones válidas y trazables; evitar ajustes manuales sin evidencia.
5. Un pago en efectivo registrado por un vendedor debe quedar asociado a su estado de liquidación.
6. El propietario debe poder confirmar cuándo recibió el efectivo del vendedor.
7. Una liquidación debe relacionarse con pagos existentes del vendedor; no crear efectivo sin origen.
8. Las constancias deben mostrar al menos folio/código, fecha, vendedor, cliente, detalle, monto y saldo cuando corresponda.
9. La consulta pública o del cliente mediante código/QR debe ser de solo lectura.
10. Las acciones críticas deben dejar bitácora de auditoría.
11. Roles mínimos: administrador y vendedor.
12. La interfaz de campo debe priorizar pocos pasos, legibilidad y uso desde teléfono.

## Flujo base de pago o abono
1. Vendedor localiza al cliente desde lista o mapa.
2. Registra el monto.
3. Sistema muestra saldo anterior, pago y saldo nuevo.
4. Al confirmar, genera folio y constancia.
5. El efectivo queda pendiente de liquidación del vendedor.
6. El propietario recibe el dinero y confirma la liquidación.

## Flujo base de entrega a crédito
1. Vendedor selecciona cliente.
2. Registra producto, cantidad, precio y vencimiento si aplica.
3. El saldo del cliente aumenta de forma trazable.
4. Se genera constancia de crédito.
5. La deuda queda disponible para seguimiento y cobro.

## Cliente y geolocalización
El expediente del cliente debe soportar nombre, contacto opcional, dirección/referencia, latitud, longitud y fotografía opcional autorizada.

El mapa es para localizar clientes y visualizar puntos. **No implementar rastreo GPS permanente de vendedores ni optimización automática de rutas en el alcance inicial.**

## Machine Learning
El repositorio puede preparar variables históricas y calidad de datos, pero **no debe emitir predicciones reales de abandono ni decisiones automáticas de crédito hasta contar con historial suficiente y validado**. La referencia del proyecto es acumular aproximadamente 3–6 meses de datos antes de evaluar el módulo predictivo.

El ML futuro busca principalmente:
- recurrencia de compra;
- reducción de frecuencia;
- posible abandono;
- temporadas altas y bajas.

## Fuera de alcance inicial
- Contabilidad general completa.
- GPS permanente de vendedores.
- Optimización automática de rutas.
- Decisión automática de otorgamiento de crédito.
- Predicciones reales de ML sin historial validado.

No ampliar el alcance silenciosamente.

## Entidades iniciales
Cliente, UbicacionCliente, Usuario, Rol, Producto, Entrega, Credito, Pago, Liquidacion, Constancia, Auditoria y VariableAnalitica.

Los nombres finales pueden adaptarse a convenciones técnicas, pero las relaciones de negocio y trazabilidad deben preservarse.

## Calidad y seguridad
- Nunca guardar credenciales, secretos ni configuraciones sensibles en Git.
- Validar autorización del lado del backend, no solo en la interfaz.
- Proteger anulaciones, liquidaciones y acciones administrativas por rol.
- Usar transacciones de base de datos en operaciones que afecten saldo, pago, crédito o liquidación.
- Diseñar pruebas para reglas financieras y de trazabilidad antes de considerar una historia terminada.
- Priorizar integridad y auditabilidad por encima de atajos de interfaz.

## Forma de trabajar con Codex
- Antes de modificar muchas áreas, explicar brevemente qué archivos se tocarán y por qué.
- Implementar por historias pequeñas y comprobables.
- Evitar reescrituras masivas si una modificación incremental resuelve la tarea.
- Añadir o actualizar pruebas junto con reglas de negocio.
- No declarar una funcionalidad terminada sin ejecutar las pruebas relevantes o explicar qué impidió ejecutarlas.
- Mantener la documentación sincronizada cuando cambie una regla aprobada.
- No inventar datos reales de clientes ni credenciales en fixtures o ejemplos.

## Prioridad de implementación
### MVP — alta prioridad
1. Modelo de datos inicial.
2. Autenticación y roles.
3. Clientes y ubicación en mapa.
4. Entregas a crédito.
5. Pagos y abonos.
6. Folios y constancias.
7. Consulta de saldo.
8. Liquidaciones.
9. Auditoría.
10. Reportes básicos de saldos y efectivo pendiente.

### Prioridad media
- QR de constancias.
- Exportación de reportes.
- Foto opcional del punto de entrega.
- Filtros por vendedor, fecha y comunidad.
- Respaldo automatizado.

### Futuro
- Indicadores de recurrencia.
- Predicción de abandono con datos validados.
- Estacionalidad.
- Recordatorios de pago.

## Presupuesto de referencia
El MVP documentado tiene un presupuesto estimado total de **Q25,000.00**. El código no debe asumir que este valor es una regla funcional, pero sí debe respetarse como contexto de alcance: priorizar un MVP práctico y controlado antes que funcionalidades accesorias.
