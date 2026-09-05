# Decisión: MySQL para la base de datos inicial

Fecha: 05/09/2026. Estado: implementada por solicitud explícita del usuario.

## Contexto y decisión

La documentación y la arquitectura inicial proponían PostgreSQL. El usuario solicitó crear la base de datos del proyecto en MySQL, ejecutarla dentro de Docker y dejar el script en la carpeta, acompañado de un archivo para Bloc de notas. Esta instrucción autoriza sustituir el motor propuesto. No había código, migraciones ni datos previos que convertir.

Se usa MySQL 8.4 LTS con InnoDB, codificación `utf8mb4`, fechas UTC, importes decimales, claves foráneas e índices. Docker usa una imagen oficial fijada por digest, un volumen persistente y un puerto publicado únicamente en `127.0.0.1`. Las contraseñas se generan localmente y se montan mediante secretos; no se incluyen en la imagen ni en Git. SQLAlchemy podrá integrarse posteriormente mediante un controlador compatible con MySQL 8.4.

## Alcance y límites

Se implementa la base de datos y sus procedimientos transaccionales iniciales, no la API, autenticación web, pantallas, mapas, emisión de PDF, impresión ni endpoint público. Una vista de constancias permite consultar información limitada; la futura API deberá autenticar usuarios internos y exponer al cliente exclusivamente una constancia por código, sin acceso directo a MySQL.

Los documentos formales RN-06 y CA-013 prohíben saldo negativo y sobrepagos sin un tratamiento autorizado. Los pagos a crédito se registran contra el saldo global del cliente: no se inventa una distribución por crédito o vencimiento. El esquema inicial contempla efectivo y ventas al contado y a crédito. Otros medios de pago requieren definir su conciliación antes de implementarlos.

Los documentos no definen cómo corregir pagos ya liquidados, ventas al contado cobradas ni créditos con abonos. Se conservan las operaciones; no se implementan devoluciones, ajustes manuales ni anulaciones que inventen un tratamiento del efectivo. El procedimiento de anulación disponible cubre abonos a crédito aún pendientes de liquidación. Los otros casos requieren diseñar y aprobar un flujo compensatorio trazable. Esto es una limitación de esta entrega, no una regla comercial nueva.

El usuario técnico del backend no podrá escribir directamente movimientos financieros. Los procedimientos validan que el identificador del actor corresponda a un usuario activo y que las acciones administrativas utilicen un administrador. La futura API debe obtener ese identificador de la sesión autenticada, nunca confiar en un ID enviado por el navegador. El administrador de infraestructura/root conserva privilegios de mantenimiento: no equivale al rol administrador del negocio.

La infraestructura es local de desarrollo. Para producción faltan el despliegue de la API, TLS y gestión externa de secretos, política de respaldo automatizado, restauraciones ensayadas y monitoreo. El respaldo manual está incluido sin activar tareas programadas.

## Referencias técnicas

- [Imagen oficial de MySQL: inicialización y secretos](https://hub.docker.com/_/mysql).
- [MySQL 8.4: bloqueos de lectura y transacciones](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html).
- [MySQL 8.4: notas de versión](https://dev.mysql.com/doc/relnotes/mysql/8.4/en/).
