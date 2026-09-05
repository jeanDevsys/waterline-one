# Arquitectura propuesta

La arquitectura se definirá definitivamente después del levantamiento de requerimientos. Esta es la propuesta inicial para el MVP.

## Componentes

| Capa | Propuesta | Responsabilidad |
|---|---|---|
| Frontend | Angular + Angular Material | Interfaz de vendedor y administrador. |
| API | FastAPI + SQLAlchemy | Reglas de negocio, autenticación y servicios. |
| Base de datos | MySQL 8.4 LTS en Docker | Clientes, operaciones, saldos, auditoría y reportes. |
| Mapas | Leaflet + OpenStreetMap | Visualización y captura de ubicaciones. |
| Analítica | Python, Pandas y scikit-learn | Preparación de datos e indicadores futuros. |
| Impresión | Impresora térmica Bluetooth o PDF | Entrega de constancias al cliente. |

## Reglas técnicas críticas

La propuesta inicial usaba PostgreSQL. El usuario solicitó explícitamente implementar MySQL en Docker el 05/09/2026. La decisión y sus límites se conservan en [08-decision-base-de-datos-mysql.md](08-decision-base-de-datos-mysql.md).

- Las operaciones confirmadas deben conservar fecha, usuario y folio.
- Un pago no se modifica: se anula con motivo y se registra el evento.
- El saldo del cliente se deriva de operaciones válidas, no se ajusta manualmente sin trazabilidad.
- Toda liquidación debe relacionarse con pagos registrados por un vendedor.
- El enlace de verificación de constancia debe ser de solo lectura.
- Las credenciales y configuraciones sensibles no deben guardarse en el repositorio.

## Entidades iniciales

Cliente, UbicaciónCliente, Usuario, Rol, Producto, Entrega, Crédito, Pago, Liquidación, Constancia, Auditoría y VariableAnalítica.
