-- Datos sintéticos para explorar Waterline One.
-- Ejecutar una vez en una base de demostración. Sin datos ni credenciales reales.

USE waterline_one;
SET SESSION time_zone = '+00:00';

-- Usuarios de prueba para registrar y liquidar.
-- Hashes de marcador; no permiten iniciar sesión.
INSERT INTO usuario (rol_id, nombre, email, password_hash, activo)
VALUES
(
  (SELECT id FROM rol WHERE codigo = 'administrador'),
  'ADMINISTRADOR DEMOSTRACION - NO REAL',
  'demo-administrador@waterline.invalid',
  'BLOQUEADO-DEMO-SIN-CREDENCIAL-REAL-0000000000000000000000000000000000',
  TRUE
),
(
  (SELECT id FROM rol WHERE codigo = 'vendedor'),
  'VENDEDOR DEMOSTRACION - NO REAL',
  'demo-vendedor@waterline.invalid',
  'BLOQUEADO-DEMO-SIN-CREDENCIAL-REAL-0000000000000000000000000000000000',
  TRUE
);

SELECT id INTO @demo_administrador_id
FROM usuario WHERE email = 'demo-administrador@waterline.invalid';

SELECT id INTO @demo_vendedor_id
FROM usuario WHERE email = 'demo-vendedor@waterline.invalid';

INSERT INTO cliente (nombre, telefono, activo, creado_por)
VALUES (
  'CLIENTE DEMOSTRACION - NO REAL',
  NULL,
  TRUE,
  @demo_administrador_id
);
SET @demo_cliente_id = LAST_INSERT_ID();

INSERT INTO ubicacion_cliente (cliente_id, direccion, comunidad, latitud, longitud, foto_url, foto_autorizada)
VALUES (
  @demo_cliente_id,
  'REFERENCIA SINTETICA PARA DEMOSTRACION; NO ES UNA DIRECCION REAL',
  'COMUNIDAD DEMOSTRACION',
  NULL,
  NULL,
  NULL,
  FALSE
);

INSERT INTO producto (codigo, nombre, unidad, precio_referencia, activo)
VALUES (
  'DEMO-AGUA-001',
  'PRODUCTO DEMOSTRACION - NO REAL',
  'garrafon',
  100.00,
  TRUE
);
SET @demo_producto_id = LAST_INSERT_ID();

-- Crédito de Q100.00.
CALL sp_registrar_entrega(
  @demo_vendedor_id,
  @demo_cliente_id,
  'CREDITO',
  JSON_ARRAY(JSON_OBJECT(
    'producto_id', CAST(@demo_producto_id AS SIGNED),
    'cantidad', CAST(1 AS SIGNED),
    'precio_unitario', CAST(100.00 AS DECIMAL(13,2))
  )),
  DATE_ADD(CURDATE(), INTERVAL 30 DAY)
);

-- Abono de Q30.00 y liquidación.
CALL sp_registrar_pago(@demo_vendedor_id, @demo_cliente_id, 30.00);
SELECT id INTO @demo_pago_liquidar_id
FROM pago
WHERE origen = 'ABONO'
ORDER BY id DESC
LIMIT 1;

CALL sp_confirmar_liquidacion(
  @demo_administrador_id,
  @demo_vendedor_id,
  JSON_ARRAY(CAST(@demo_pago_liquidar_id AS SIGNED))
);

-- Abono de Q10.00 anulado.
CALL sp_registrar_pago(@demo_vendedor_id, @demo_cliente_id, 10.00);
SELECT id INTO @demo_pago_anular_id
FROM pago
WHERE origen = 'ABONO'
  AND id <> @demo_pago_liquidar_id
ORDER BY id DESC
LIMIT 1;

CALL sp_anular_pago(
  @demo_administrador_id,
  @demo_pago_anular_id,
  'ANULACION DE DEMOSTRACION - NO REAL',
  'EVIDENCIA SINTETICA PARA PROBAR AUDITORIA'
);

-- Métrica descriptiva de ejemplo.
INSERT INTO variable_analitica (
  cliente_id,
  periodo_inicio,
  periodo_fin,
  numero_entregas,
  monto_compras,
  dias_desde_ultima_entrega,
  fuente_version
)
VALUES (
  @demo_cliente_id,
  CURDATE(),
  CURDATE(),
  1,
  100.00,
  0,
  'demostracion-v1'
);

-- Consultas para Workbench.
SELECT * FROM v_saldos_clientes WHERE cliente_id = @demo_cliente_id;
SELECT * FROM v_estado_pagos WHERE cliente_id = @demo_cliente_id;
SELECT * FROM v_efectivo_pendiente WHERE vendedor_id = @demo_vendedor_id;
