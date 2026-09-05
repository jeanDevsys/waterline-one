# Flujo de cobros y constancias

## Principio de control

Cada operación confirmada obtiene un **folio único** y una **constancia**. El cliente recibe una copia impresa; el sistema conserva la copia digital. No se elimina un movimiento confirmado: si hubo error, un administrador lo anula con un motivo y queda registrado.

## Pago o abono

1. El vendedor busca al cliente desde la lista o el mapa.
2. Selecciona “Registrar pago” e ingresa el monto.
3. El sistema muestra saldo anterior, monto pagado y saldo nuevo.
4. Se confirma el movimiento y se genera folio, código corto y QR opcional.
5. Se imprime la constancia para el cliente.
6. El efectivo queda en estado **pendiente de liquidación** del vendedor.
7. El propietario recibe el efectivo y registra la liquidación.

## Entrega a crédito

1. El vendedor selecciona al cliente.
2. Registra producto, cantidad, precio y fecha de vencimiento si aplica.
3. El sistema incrementa el saldo del cliente.
4. Se genera una constancia de entrega a crédito.
5. La operación queda disponible para seguimiento y cobro posterior.

## Verificación simple para el cliente

El cliente no necesita instalar una aplicación. Puede:

- revisar su constancia impresa;
- proporcionar el folio o código corto al negocio;
- escanear un QR para abrir una consulta de solo lectura, si tiene teléfono.

## Estados de efectivo

| Estado | Significado |
|---|---|
| Registrado | El vendedor confirmó un pago. |
| Pendiente de liquidación | El vendedor conserva el efectivo registrado. |
| Liquidado | El administrador confirmó recepción del efectivo. |
| Anulado | Un administrador anuló la operación y dejó motivo. |