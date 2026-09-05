# Alcance y etapas

## Alcance del MVP

El MVP cubrirá el ciclo completo de clientes, crédito, cobro y liquidación:

- catálogo y ubicación geográfica de clientes;
- registro de entregas al contado y a crédito;
- registro de pagos y abonos;
- constancias con folio y código verificable;
- saldo por cliente;
- liquidación de efectivo por vendedor;
- roles, bitácora y reportes básicos.

## Etapas

| Etapa | Objetivo | Entregables |
|---|---|---|
| 0. Levantamiento | Comprender el proceso real de negocio. | Entrevistas, requerimientos validados y diagramas. |
| 1. Diseño | Definir experiencia, datos y reglas. | Prototipos, modelo de datos y casos de uso. |
| 2. Waterline Campo | Digitalizar la operación del vendedor. | Clientes, mapa, créditos, pagos y constancias. |
| 3. Waterline Control | Dar control al propietario. | Liquidaciones, auditoría, conciliación y reportes. |
| 4. Waterline Análisis | Preparar información útil para decisiones. | Indicadores, calidad de datos y base para ML. |
| 5. Validación | Probar con usuarios reales. | Pruebas, capacitación, manuales y despliegue piloto. |

## Criterio para machine learning

El módulo analítico se preparará desde el inicio, pero las predicciones reales permanecerán bloqueadas hasta reunir varios meses de datos completos y verificados. Antes de eso, solo se mostrarán indicadores descriptivos, por ejemplo frecuencia de compra y saldos pendientes.