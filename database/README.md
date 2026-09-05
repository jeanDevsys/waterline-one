# Base de datos de Waterline One

La implementación usa **MySQL 8.4 LTS**, por solicitud expresa del usuario del 5 de septiembre de 2026. Esta decisión sustituye únicamente la propuesta de PostgreSQL de los documentos originales. Mantiene las reglas del proyecto y no cambia Angular, FastAPI ni el alcance funcional.

`001_waterline_one.sql` crea la base `waterline_one`, tablas, restricciones, índices, vistas, procedimientos, disparadores de inmutabilidad y el rol SQL `wl_app_role`. El contenedor lo ejecuta al inicializar un volumen vacío. No contiene contraseñas ni clientes o usuarios de ejemplo; únicamente carga los roles de negocio `administrador` y `vendedor`.

El despliegue, los comandos de conexión y el respaldo están en [BASE_DE_DATOS_MYSQL.txt](../BASE_DE_DATOS_MYSQL.txt). El archivo SQL se puede abrir con Bloc de notas. No se debe volver a ejecutar esta migración sobre una base inicializada: los siguientes cambios deben ser migraciones nuevas, revisadas y respaldadas. MySQL confirma DDL de forma implícita; un fallo de inicialización se investiga antes de reutilizar los datos.

## Modelo

| Tablas | Propósito y relación |
|---|---|
| `rol`, `usuario` | Un rol mínimo por usuario; cuenta activa/inactiva y hash de contraseña. |
| `cliente`, `ubicacion_cliente` | Expediente y una ubicación actual por cliente. Teléfono opcional; referencia textual o coordenadas completas. |
| `producto` | Catálogo con código único, unidad y precio de referencia. El precio confirmado queda en el detalle de la entrega. |
| `operacion` | Cabecera común de todos los movimientos: folio global, fecha UTC, responsable, cliente cuando corresponde, importe y saldos históricos. |
| `entrega`, `entrega_detalle`, `credito` | Entrega con múltiples productos. Un crédito corresponde a una entrega a crédito y puede tener vencimiento. |
| `pago` | Abono al saldo o cobro de una entrega al contado; todo pago del MVP representa efectivo. |
| `anulacion_pago` | Evento administrativo separado, con motivo y evidencia; referencia única al pago original. |
| `liquidacion`, `liquidacion_pago` | Recepción de efectivo por administrador. Cada pago puede pertenecer a una sola liquidación. |
| `constancia` | Instantánea JSON inmutable, folio asociado, código de soporte y token aleatorio de consulta. |
| `auditoria` | Registro adicional inmutable de cada operación financiera, con actor, fecha, detalle y conexión SQL. |
| `variable_analitica` | Históricos descriptivos por período y versión del cálculo; no incluye predicciones ni decisiones de crédito. |

Las tablas de subtipo `entrega`, `pago`, `liquidacion` y `anulacion_pago` comparten su `id` con `operacion.id`. `credito.entrega_id` identifica su entrega. Esto centraliza importes, autoría, fecha y folios sin duplicarlos entre tablas. Las copias de nombre y unidad del producto, saldos y contenido de constancia son evidencia histórica intencional: no cambian al actualizar un catálogo.

## Integridad y dinero

- Todas las tablas son InnoDB con claves primarias y foráneas; las relaciones usan `ON DELETE RESTRICT` y `ON UPDATE RESTRICT`.
- La codificación es `utf8mb4`; folios, tokens y hashes emplean comparación ASCII sensible a mayúsculas. Los correos y códigos de catálogo son únicos sin distinguir mayúsculas bajo la intercalación general.
- La fecha se almacena como `DATETIME(6)` UTC mediante `UTC_TIMESTAMP(6)`. La presentación en la zona de Guatemala corresponde a la aplicación.
- Los importes individuales usan `DECIMAL(13,2)`; los saldos históricos, `DECIMAL(15,2)`. No se utiliza `FLOAT` ni `DOUBLE` para dinero. Los valores son quetzales (GTQ).
- Las cantidades admiten tres decimales y el precio unitario dos. El subtotal se redondea a centavos por renglón; el total es la suma de esos subtotales. No se admite un subtotal de cero ni desbordamientos.
- Cada movimiento confirmado obtiene un UUID como folio con una restricción `UNIQUE` global. Los saltos del autoincremento por transacciones fallidas son normales; el identificador no representa una numeración fiscal.
- `v_saldos_clientes` calcula **créditos menos abonos válidos**. No existe una columna editable de saldo actual. Un pago al contado no descuenta una deuda previa.
- Las constancias, la auditoría y todas las tablas financieras bloquean `UPDATE` y `DELETE` mediante disparadores. La cuenta de aplicación tampoco recibe permisos de escritura directa en ellas. Un DBA con permisos DDL sigue siendo una cuenta de confianza capaz de cambiar el esquema; los respaldos y el control de acceso siguen siendo necesarios.
- Los procedimientos confirman juntos movimiento, detalle, constancia y auditoría. Ante cualquier excepción, ejecutan `ROLLBACK` y propagan el error.
- Un bloqueo `SELECT ... FOR UPDATE` por vendedor y después por cliente serializa el efectivo y los cambios del saldo. Cada operación utiliza aislamiento `READ COMMITTED` para leer el saldo vigente después de esperar el bloqueo. Las liquidaciones bloquean al vendedor y sus pagos; las anulaciones comparten ese orden.

## Contrato de los procedimientos

Los siguientes procedimientos son la **única escritura financeira autorizada para `wl_app_role`**. Se invocan individualmente desde conexiones con autocommit habilitado, sin una transacción exterior: cada `CALL` controla su propia transacción. El backend debe consumir el resultado y todos los conjuntos de resultados del controlador antes de reutilizar la conexión.

`p_actor_id` siempre debe provenir de la sesión autenticada del backend. Los procedimientos comprueban que el actor existe, está activo y tiene el rol permitido, pero un ID **no autentica** a una persona. Nunca se debe entregar la credencial SQL de la aplicación a vendedores, clientes ni al navegador. No se ha implementado todavía la API ni el inicio de sesión.

### Registrar entrega

```sql
CALL sp_registrar_entrega(
    p_actor_id,       -- BIGINT UNSIGNED; vendedor o administrador activo
    p_cliente_id,     -- BIGINT UNSIGNED; cliente activo con ubicación
    p_modalidad,      -- VARCHAR(10): 'CREDITO' o 'CONTADO'
    p_detalles,       -- JSON: arreglo de 1 a 200 renglones
    p_vencimiento    -- DATE o NULL; sólo para CREDITO
);
```

Cada renglón contiene `producto_id` entero, `cantidad` numérica y `precio_unitario` numérico. Los identificadores corresponden a productos existentes y activos. La estructura es `[{"producto_id": ID_EXISTENTE, "cantidad": 2, "precio_unitario": 10.50}]`; `ID_EXISTENTE` es un marcador, no un dato precargado. Se registra el precio confirmado, que puede diferir del precio de referencia.

Retorna `entrega_id`, `pago_id`, `folio`, `saldo_anterior`, `saldo_nuevo`, `token_publico`. A crédito, `pago_id` es `NULL` y el saldo aumenta. Al contado, genera también un pago vinculado a la entrega y pendiente de liquidación; el saldo de crédito no cambia. Tanto la entrega como su pago tienen su propio folio, constancia y auditoría.

### Registrar pago o abono

```sql
CALL sp_registrar_pago(
    p_actor_id,       -- BIGINT UNSIGNED; vendedor o administrador activo
    p_cliente_id,     -- BIGINT UNSIGNED; cliente activo con ubicación
    p_monto           -- DECIMAL(18,6); se valida a centavos, > 0 y <= saldo
);
```

Retorna `pago_id`, `folio`, `saldo_anterior`, `saldo_nuevo`, `token_publico`. Rechaza montos nulos, cero, negativos, fracciones de centavo dentro de la precisión del parámetro, exceso de rango y sobrepagos. El backend debe validar la precisión antes de convertir sus entradas, para no redondearlas al enviarlas. El efectivo queda pendiente del usuario que lo registró.

### Confirmar liquidación

```sql
CALL sp_confirmar_liquidacion(
    p_actor_id,       -- BIGINT UNSIGNED; sólo administrador activo
    p_vendedor_id,    -- BIGINT UNSIGNED; titular del efectivo
    p_pago_ids        -- JSON: arreglo de 1 a 1000 IDs de pagos existentes
);
```

Retorna `liquidacion_id`, `folio`, `monto`, `token_publico`. El importe se calcula desde los pagos; no se recibe un total manual. Todos deben pertenecer al vendedor, seguir pendientes y aparecer una sola vez. Rechaza pagos inexistentes, anulados o ya liquidados y revierte el conjunto completo ante cualquier error. Se permite liquidar efectivo histórico de un vendedor desactivado. La creación representa la recepción confirmada por el administrador; no se implementa una etapa de borrador.

### Anular pago

```sql
CALL sp_anular_pago(
    p_actor_id,       -- BIGINT UNSIGNED; sólo administrador activo
    p_pago_id,        -- BIGINT UNSIGNED
    p_motivo,         -- VARCHAR(500), obligatorio y no vacío
    p_evidencia       -- VARCHAR(1000), referencia o descripción no vacía
);
```

Retorna `anulacion_id`, `pago_id`, `folio`, `saldo_anterior`, `saldo_nuevo`, `token_publico`. Conserva el pago original, crea el evento de anulación y su constancia, restaura el saldo y excluye el importe del efectivo pendiente. Exige motivo y evidencia y prohíbe anular dos veces el mismo pago.

Las anulaciones de pagos ya liquidados y de pagos al contado están bloqueadas. La documentación no define todavía cómo devolver o compensar efectivo recibido ni cómo corregir conjuntamente una entrega al contado. Tampoco se incluyen anulaciones de créditos, descuentos manuales ni devoluciones. Estas reglas requieren definición de negocio y una migración posterior; no deben resolverse editando las tablas.

Los abonos se aplican al saldo global del cliente. No se inventa una regla FIFO ni se distribuyen entre créditos particulares; el saldo por crédito y su asignación de abonos requieren una regla futura aprobada. Un error de conexión después de confirmar puede dejar el resultado desconocido para el backend: antes de repetir una operación debe conciliarse por los movimientos existentes. La API futura debe agregar una clave de idempotencia a sus solicitudes y una migración que la respalde; todavía no existe una interfaz HTTP.

## Consultas y comprobantes

| Vista | Resultado |
|---|---|
| `v_saldos_clientes` | `cliente_id`, `total_creditos`, `total_abonos`, `saldo`; incluye clientes sin movimientos con saldo cero. |
| `v_estado_pagos` | Identidad y folio del pago, fecha, vendedor, cliente, monto, origen, estado `PENDIENTE`/`LIQUIDADO`/`ANULADO`, liquidación asociada. |
| `v_efectivo_pendiente` | `vendedor_id`, `pagos_pendientes`, `efectivo_pendiente`; sólo vendedores con pagos pendientes. |
| `v_usuarios` | Datos del usuario y rol sin su hash de contraseña. |
| `v_constancias_publicas` | Token, código, folio, fecha, tipo, contenido histórico y estado vigente o anulado; excluye liquidaciones internas. |

La constancia contiene versión de estructura, fecha UTC, folio, cliente, vendedor, responsable, detalle, GTQ, monto y saldos cuando corresponden. El nombre del vendedor de una anulación es el del pago original; el responsable es el administrador que la autoriza. La evidencia administrativa no se incluye en la constancia pública.

El código de doce caracteres hexadecimales sirve para soporte y búsqueda por el negocio. La consulta pública futura debe usar el token aleatorio de 32 bytes, buscar **una sola constancia**, ser de sólo lectura y limitar intentos. No se debe publicar una lista ni conceder acceso SQL al público. El folio UUID y el código corto no sustituyen el token como secreto de acceso. `contenido` permanece intacto tras una anulación; el estado vigente se deriva del evento separado.

## Acceso y aprovisionamiento

`wl_app_role` dispone de `SELECT` sobre los catálogos y datos operativos necesarios, y de `EXECUTE` sobre los cuatro procedimientos públicos. No tiene `INSERT`, `UPDATE`, `DELETE`, `DDL`, gestión de usuarios ni ejecución de los helpers privados. Tampoco puede leer `usuarios.password_hash`. El rol no incluye permisos globales sobre `waterline_one.*` que permitan escribir en futuras tablas sin revisión.

La carga inicial de usuarios, clientes, ubicaciones y productos corresponde al DBA en una sesión local controlada. El primer administrador debe disponer de un hash real generado por la capa de autenticación, preferentemente Argon2id, nunca de una contraseña en texto plano. El `CHECK` de longitud del hash evita entradas demasiado cortas, pero no valida criptográficamente su formato. No se han creado cuentas humanas ni credenciales de muestra. La gestión y autenticación de usuarios, así como el CRUD auditado de catálogos desde la API, quedan para sus historias de implementación; no se concede escritura directa a la aplicación como atajo.

Las pruebas usan identidades explícitamente sintéticas dentro de un contenedor temporal, sin cargar esos datos en desarrollo. Los datos de analítica no se rellenan automáticamente ni emiten predicciones: su proceso de cálculo y validación del historial es futuro.

## Validación

Ejecutar desde la raíz del proyecto:

```powershell
python tests/database/test_mysql.py
```

La suite crea una base temporal aislada y verifica flujos financieros, restricciones, permisos, inmutabilidad, comprobantes, anulaciones, liquidaciones y concurrencia. No reutiliza los datos del contenedor de desarrollo. Las pruebas de reglas de negocio deben ampliarse al aprobar nuevos movimientos o cambiar una regla.

Referencias técnicas: [transacciones y aislamiento de InnoDB](https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-isolation-levels.html), [disparadores de MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/trigger-syntax.html), [JSON_TABLE](https://dev.mysql.com/doc/refman/8.4/en/json-table-functions.html).
