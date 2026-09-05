# Waterline One

> Cada entrega. Cada pago. Bajo control.

Waterline One es una plataforma web para una empresa distribuidora de agua. Centraliza la ubicación de clientes, entregas, créditos, pagos, liquidaciones y evidencia verificable de cada movimiento.

## Módulos

- **Waterline Campo:** uso diario de vendedores: clientes, mapa, entregas, créditos, pagos y constancias.
- **Waterline Control:** uso del propietario o administrador: liquidaciones, auditoría, conciliación y reportes.
- **Waterline Análisis:** indicadores de ventas, calidad de datos y preparación para análisis predictivo futuro.

## Problema que resuelve

Cuando un vendedor entrega producto a crédito o recibe un pago, el propietario necesita saber qué ocurrió, a qué cliente, en qué ubicación, con qué comprobante y cuándo se liquidó el efectivo. Waterline One convierte esos movimientos en registros trazables y auditables.

## Estado del proyecto

El proyecto cuenta con documentación de análisis y una base de datos inicial MySQL 8.4 en Docker. El frontend y la API todavía están pendientes.

## Base de datos local

Con Docker Desktop iniciado en modo de contenedores Linux, ejecutar desde la raíz en PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\infra\mysql\Start-Database.ps1
```

Esto genera credenciales locales, construye la imagen e inicializa `waterline_one` en un volumen persistente. Conexión: `127.0.0.1:3306`, usuario técnico `waterline_app`; contraseña en `.secrets/mysql_app_password.txt` (excluida de Git). Los roles de usuarios del negocio se validarán además en la API; esta cuenta SQL no es un inicio de sesión de vendedor.

- [Instrucciones para Bloc de notas](BASE_DE_DATOS_MYSQL.txt).
- [Script SQL](database/001_waterline_one.sql) y [copia para Bloc de notas](SCRIPT_BASE_DE_DATOS_MYSQL.txt).
- [Modelo, procedimientos y límites](database/README.md).
- [Decisión de usar MySQL](docs/08-decision-base-de-datos-mysql.md).

Los scripts de inicialización se ejecutan únicamente sobre un volumen vacío. Los cambios futuros requieren migraciones incrementales; reconstruir la imagen no migra datos existentes.

## Documentación

- [Contexto y problema](docs/01-contexto-y-problema.md)
- [Requerimientos preliminares](docs/02-requerimientos-preliminares.md)
- [Flujo de cobros y constancias](docs/03-flujo-de-cobros.md)
- [Alcance y etapas](docs/04-alcance-y-etapas.md)
- [Presupuesto](docs/05-presupuesto.md)
- [Arquitectura propuesta](docs/06-arquitectura.md)
- [Backlog inicial](docs/07-backlog-inicial.md)

## Estructura

```text
frontend/   Aplicación web
backend/    API y reglas de negocio
database/   Modelo y migraciones
ml/         Preparación de datos y análisis futuro
infra/      Despliegue, respaldos y configuración
tests/      Pruebas funcionales y técnicas
docs/       Documentación del proyecto
```

---
El módulo de aprendizaje automático no emitirá predicciones reales hasta contar con datos históricos suficientes y validados.


## Documentación formal de análisis

Los documentos editables de inicio se encuentran en `docs/formales/`:

- [Acta de Constitución del Proyecto](<docs/formales/01_Acta_de_Constitucion_Waterline_One (1).docx>)
- [Identificación de Módulos del Sistema](<docs/formales/02_Identificacion_de_Modulos_Waterline_One (1).docx>)
- [Documento de Reglas de Negocio](<docs/formales/03_Reglas_de_Negocio_Waterline_One (1).docx>)
- [Especificación de Reglas de Negocio](<docs/formales/04_Especificacion_de_Reglas_Waterline_One (1).docx>)
- [Criterios de Aceptación](<docs/formales/05_Criterios_de_Aceptacion_Waterline_One (1).docx>)
