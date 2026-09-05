# Requerimientos preliminares

Estos requerimientos son una primera base. Deben validarse con el propietario y los vendedores durante el levantamiento formal.

## Funcionales

1. Registrar clientes con nombre, teléfono opcional, dirección de referencia y ubicación en mapa.
2. Visualizar clientes como puntos en un mapa para facilitar su localización.
3. Registrar entrega al contado, entrega a crédito, pago total y abono.
4. Calcular el saldo pendiente de cada cliente.
5. Generar una constancia imprimible para cada pago o entrega a crédito.
6. Incluir en la constancia: folio, código corto, fecha, vendedor, cliente, detalle, monto y saldo.
7. Permitir verificar una constancia mediante folio, código o código QR.
8. Registrar el efectivo recibido por vendedor como pendiente de liquidación.
9. Permitir al administrador marcar una liquidación como recibida y conciliada.
10. Mostrar reportes de créditos, pagos, ventas, saldos y liquidaciones.
11. Mantener una bitácora de acciones importantes: creación, anulación y ajustes.
12. Gestionar roles de administrador y vendedor.
13. Preparar variables históricas para análisis de recurrencia y posible abandono.

## No funcionales

- Interfaz clara y con pocos pasos para uso en campo.
- Diseño adaptable a teléfono, tablet y computadora.
- Folios únicos y registros no editables después de confirmarse.
- Anulaciones solo por administrador, con motivo y evidencia en bitácora.
- Respaldo periódico de la información.
- Control de acceso mediante cuentas y contraseñas seguras.
- Comprobantes legibles para clientes con baja familiaridad tecnológica.

## Fuera de alcance inicial

- Contabilidad general completa.
- Rastreo GPS permanente de vendedores.
- Optimización automática de rutas.
- Decisión automática de otorgamiento de crédito.
- Predicciones reales de machine learning sin historial validado.