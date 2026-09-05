-- Waterline One: esquema inicial para MySQL 8.4.
-- Ejecutar una sola vez en una base vacía. Sin secretos ni datos reales.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION time_zone = '+00:00';
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION,ONLY_FULL_GROUP_BY';

CREATE DATABASE IF NOT EXISTS waterline_one CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE waterline_one;

CREATE TABLE rol (
    id TINYINT UNSIGNED PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT ck_roles_codigo CHECK (codigo IN ('administrador', 'vendedor'))
) ENGINE=InnoDB;

INSERT INTO rol (id, codigo) VALUES (1, 'administrador'), (2, 'vendedor');

CREATE TABLE usuario (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    rol_id TINYINT UNSIGNED NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (rol_id) REFERENCES rol(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_usuarios_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_usuarios_email CHECK (CHAR_LENGTH(TRIM(email)) > 3),
    CONSTRAINT ck_usuarios_hash CHECK (CHAR_LENGTH(password_hash) >= 60),
    CONSTRAINT ck_usuarios_activo CHECK (activo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE cliente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(180) NOT NULL,
    telefono VARCHAR(40) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por BIGINT UNSIGNED NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    INDEX ix_clientes_nombre (nombre),
    CONSTRAINT fk_clientes_creador FOREIGN KEY (creado_por) REFERENCES usuario(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_clientes_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_clientes_activo CHECK (activo IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE ubicacion_cliente (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cliente_id BIGINT UNSIGNED NOT NULL UNIQUE,
    direccion VARCHAR(500) NULL,
    comunidad VARCHAR(120) NULL,
    latitud DECIMAL(9,6) NULL,
    longitud DECIMAL(9,6) NULL,
    foto_url VARCHAR(1000) NULL,
    foto_autorizada BOOLEAN NOT NULL DEFAULT FALSE,
    INDEX ix_ubicaciones_comunidad (comunidad),
    CONSTRAINT fk_ubicacion_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_ubicacion_par CHECK ((latitud IS NULL AND longitud IS NULL) OR (latitud IS NOT NULL AND longitud IS NOT NULL)),
    CONSTRAINT ck_ubicacion_lat CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
    CONSTRAINT ck_ubicacion_lon CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180),
    CONSTRAINT ck_ubicacion_referencia CHECK (COALESCE(CHAR_LENGTH(TRIM(direccion)),0) > 0 OR (latitud IS NOT NULL AND longitud IS NOT NULL)),
    CONSTRAINT ck_ubicacion_foto CHECK (foto_url IS NULL OR foto_autorizada = 1),
    CONSTRAINT ck_ubicacion_autorizacion CHECK (foto_autorizada IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE producto (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    unidad VARCHAR(30) NOT NULL DEFAULT 'unidad',
    precio_referencia DECIMAL(13,2) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    CONSTRAINT ck_producto_codigo CHECK (CHAR_LENGTH(TRIM(codigo)) > 0),
    CONSTRAINT ck_producto_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_producto_unidad CHECK (CHAR_LENGTH(TRIM(unidad)) > 0),
    CONSTRAINT ck_producto_precio CHECK (precio_referencia > 0),
    CONSTRAINT ck_producto_activo CHECK (activo IN (0,1))
) ENGINE=InnoDB;

-- Folio único global; los subtipos comparten la misma operación.
CREATE TABLE operacion (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    folio CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    tipo ENUM('ENTREGA_CREDITO','ENTREGA_CONTADO','PAGO_ABONO','PAGO_CONTADO','LIQUIDACION','ANULACION_PAGO') NOT NULL,
    fecha DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    usuario_id BIGINT UNSIGNED NOT NULL,
    cliente_id BIGINT UNSIGNED NULL,
    monto DECIMAL(13,2) NOT NULL,
    saldo_anterior DECIMAL(15,2) NULL,
    saldo_nuevo DECIMAL(15,2) NULL,
    INDEX ix_operaciones_cliente_fecha (cliente_id, fecha, id),
    INDEX ix_operaciones_usuario_fecha (usuario_id, fecha, id),
    INDEX ix_operaciones_tipo_fecha (tipo, fecha, id),
    CONSTRAINT fk_operacion_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_operacion_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_operacion_monto CHECK (monto > 0),
    CONSTRAINT ck_operacion_saldos CHECK (
        (tipo = 'LIQUIDACION' AND cliente_id IS NULL AND saldo_anterior IS NULL AND saldo_nuevo IS NULL)
        OR (tipo <> 'LIQUIDACION' AND cliente_id IS NOT NULL AND saldo_anterior IS NOT NULL AND saldo_nuevo IS NOT NULL AND saldo_anterior >= 0 AND saldo_nuevo >= 0)
    )
) ENGINE=InnoDB;

CREATE TABLE entrega (
    id BIGINT UNSIGNED PRIMARY KEY,
    modalidad ENUM('CREDITO','CONTADO') NOT NULL,
    CONSTRAINT fk_entrega_operacion FOREIGN KEY (id) REFERENCES operacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE entrega_detalle (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    entrega_id BIGINT UNSIGNED NOT NULL,
    renglon SMALLINT UNSIGNED NOT NULL,
    producto_id BIGINT UNSIGNED NOT NULL,
    producto_nombre VARCHAR(150) NOT NULL COMMENT 'Nombre historico al confirmar',
    unidad VARCHAR(30) NOT NULL COMMENT 'Unidad historica al confirmar',
    cantidad DECIMAL(12,3) NOT NULL,
    precio_unitario DECIMAL(13,2) NOT NULL,
    subtotal DECIMAL(13,2) GENERATED ALWAYS AS (ROUND(cantidad * precio_unitario, 2)) STORED,
    UNIQUE KEY uq_entrega_renglon (entrega_id, renglon),
    CONSTRAINT fk_detalle_entrega FOREIGN KEY (entrega_id) REFERENCES entrega(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id) REFERENCES producto(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio CHECK (precio_unitario > 0),
    CONSTRAINT ck_detalle_subtotal CHECK (subtotal > 0)
) ENGINE=InnoDB;

CREATE TABLE credito (
    entrega_id BIGINT UNSIGNED PRIMARY KEY,
    vencimiento DATE NULL,
    INDEX ix_creditos_vencimiento (vencimiento),
    CONSTRAINT fk_credito_entrega FOREIGN KEY (entrega_id) REFERENCES entrega(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE pago (
    id BIGINT UNSIGNED PRIMARY KEY,
    origen ENUM('ABONO','CONTADO') NOT NULL,
    entrega_id BIGINT UNSIGNED NULL UNIQUE,
    CONSTRAINT fk_pago_operacion FOREIGN KEY (id) REFERENCES operacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_pago_entrega FOREIGN KEY (entrega_id) REFERENCES entrega(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_pago_origen CHECK ((origen = 'ABONO' AND entrega_id IS NULL) OR (origen = 'CONTADO' AND entrega_id IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE anulacion_pago (
    id BIGINT UNSIGNED PRIMARY KEY,
    pago_id BIGINT UNSIGNED NOT NULL UNIQUE,
    motivo VARCHAR(500) NOT NULL,
    evidencia VARCHAR(1000) NOT NULL COMMENT 'Referencia o descripcion de evidencia; nunca secretos',
    CONSTRAINT fk_anulacion_operacion FOREIGN KEY (id) REFERENCES operacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_anulacion_pago FOREIGN KEY (pago_id) REFERENCES pago(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_anulacion_motivo CHECK (CHAR_LENGTH(TRIM(motivo)) > 0),
    CONSTRAINT ck_anulacion_evidencia CHECK (CHAR_LENGTH(TRIM(evidencia)) > 0)
) ENGINE=InnoDB;

CREATE TABLE liquidacion (
    id BIGINT UNSIGNED PRIMARY KEY,
    vendedor_id BIGINT UNSIGNED NOT NULL,
    INDEX ix_liquidaciones_vendedor (vendedor_id, id),
    CONSTRAINT fk_liquidacion_operacion FOREIGN KEY (id) REFERENCES operacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_liquidacion_vendedor FOREIGN KEY (vendedor_id) REFERENCES usuario(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE liquidacion_pago (
    liquidacion_id BIGINT UNSIGNED NOT NULL,
    pago_id BIGINT UNSIGNED NOT NULL UNIQUE,
    PRIMARY KEY (liquidacion_id, pago_id),
    CONSTRAINT fk_lp_liquidacion FOREIGN KEY (liquidacion_id) REFERENCES liquidacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_lp_pago FOREIGN KEY (pago_id) REFERENCES pago(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE constancia (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    operacion_id BIGINT UNSIGNED NOT NULL UNIQUE,
    codigo CHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    token_publico CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
    contenido JSON NOT NULL COMMENT 'Instantanea inmutable; version 1; importes en GTQ; fecha UTC',
    emitida_en DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    CONSTRAINT fk_constancia_operacion FOREIGN KEY (operacion_id) REFERENCES operacion(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE auditoria (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    actor_id BIGINT UNSIGNED NOT NULL,
    accion VARCHAR(60) NOT NULL,
    entidad VARCHAR(60) NOT NULL,
    entidad_id BIGINT UNSIGNED NOT NULL,
    detalle JSON NOT NULL,
    usuario_bd VARCHAR(288) NOT NULL,
    INDEX ix_auditoria_entidad (entidad, entidad_id, fecha),
    INDEX ix_auditoria_actor_fecha (actor_id, fecha),
    CONSTRAINT fk_auditoria_actor FOREIGN KEY (actor_id) REFERENCES usuario(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE variable_analitica (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cliente_id BIGINT UNSIGNED NOT NULL,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    numero_entregas INT UNSIGNED NOT NULL,
    monto_compras DECIMAL(15,2) NOT NULL,
    dias_desde_ultima_entrega INT UNSIGNED NULL,
    fuente_version VARCHAR(80) NOT NULL,
    calculado_en DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6)),
    UNIQUE KEY uq_variable_periodo (cliente_id, periodo_inicio, periodo_fin, fuente_version),
    CONSTRAINT fk_variable_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_variable_periodo CHECK (periodo_fin >= periodo_inicio),
    CONSTRAINT ck_variable_monto CHECK (monto_compras >= 0)
) ENGINE=InnoDB;

CREATE SQL SECURITY DEFINER VIEW v_usuarios AS
SELECT u.id, u.nombre, u.email, r.codigo AS rol, u.activo, u.creado_en
FROM usuario u JOIN rol r ON r.id = u.rol_id;

CREATE SQL SECURITY DEFINER VIEW v_saldos_clientes AS
SELECT c.id AS cliente_id,
       COALESCE(cr.total_creditos, 0.00) AS total_creditos,
       COALESCE(pa.total_abonos, 0.00) AS total_abonos,
       COALESCE(cr.total_creditos, 0.00) - COALESCE(pa.total_abonos, 0.00) AS saldo
FROM cliente c
LEFT JOIN (
    SELECT o.cliente_id, SUM(o.monto) AS total_creditos
    FROM credito cr JOIN operacion o ON o.id = cr.entrega_id GROUP BY o.cliente_id
) cr ON cr.cliente_id = c.id
LEFT JOIN (
    SELECT o.cliente_id, SUM(o.monto) AS total_abonos
    FROM pago p JOIN operacion o ON o.id = p.id
    LEFT JOIN anulacion_pago a ON a.pago_id = p.id
    WHERE p.origen = 'ABONO' AND a.id IS NULL GROUP BY o.cliente_id
) pa ON pa.cliente_id = c.id;

CREATE SQL SECURITY DEFINER VIEW v_estado_pagos AS
SELECT p.id AS pago_id, o.folio, o.fecha, o.usuario_id AS vendedor_id,
       o.cliente_id, o.monto, p.origen,
       CASE WHEN a.id IS NOT NULL THEN 'ANULADO'
            WHEN lp.pago_id IS NOT NULL THEN 'LIQUIDADO' ELSE 'PENDIENTE' END AS estado,
       lp.liquidacion_id
FROM pago p JOIN operacion o ON o.id = p.id
LEFT JOIN anulacion_pago a ON a.pago_id = p.id
LEFT JOIN liquidacion_pago lp ON lp.pago_id = p.id;

CREATE SQL SECURITY DEFINER VIEW v_efectivo_pendiente AS
SELECT vendedor_id, COUNT(*) AS pagos_pendientes, SUM(monto) AS efectivo_pendiente
FROM v_estado_pagos WHERE estado = 'PENDIENTE' GROUP BY vendedor_id;

-- Vista pública para uso exclusivo de la API.
CREATE SQL SECURITY DEFINER VIEW v_constancias_publicas AS
SELECT c.token_publico, c.codigo, o.folio, o.fecha, o.tipo, c.contenido,
       CASE WHEN a.id IS NULL THEN 'VIGENTE' ELSE 'ANULADO' END AS estado
FROM constancia c JOIN operacion o ON o.id = c.operacion_id
LEFT JOIN anulacion_pago a ON a.pago_id = o.id
WHERE o.cliente_id IS NOT NULL;

DELIMITER $$

-- Helpers internos.
CREATE PROCEDURE sp__validar_actor(IN p_actor_id BIGINT UNSIGNED, IN p_solo_admin BOOLEAN)
SQL SECURITY DEFINER
READS SQL DATA
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM usuario u JOIN rol r ON r.id = u.rol_id
        WHERE u.id = p_actor_id AND u.activo = 1
          AND (r.codigo = 'administrador' OR (NOT p_solo_admin AND r.codigo = 'vendedor'))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor inexistente, inactivo o sin permiso para esta operacion';
    END IF;
END$$

CREATE PROCEDURE sp__emitir_constancia(IN p_operacion_id BIGINT UNSIGNED, IN p_detalle JSON)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    INSERT INTO constancia (operacion_id, codigo, token_publico, contenido)
    SELECT o.id, UPPER(HEX(RANDOM_BYTES(6))), LOWER(HEX(RANDOM_BYTES(32))),
           JSON_OBJECT('version', 1, 'folio', o.folio, 'fecha_utc', DATE_FORMAT(o.fecha,'%Y-%m-%dT%H:%i:%s.%fZ'),
                       'tipo', o.tipo, 'cliente', c.nombre, 'vendedor', uv.nombre, 'responsable', u.nombre,
                       'detalle', p_detalle, 'moneda', 'GTQ', 'monto', o.monto,
                       'saldo_anterior', o.saldo_anterior, 'saldo_nuevo', o.saldo_nuevo)
    FROM operacion o JOIN usuario u ON u.id = o.usuario_id
    LEFT JOIN cliente c ON c.id = o.cliente_id
    LEFT JOIN liquidacion l ON l.id = o.id
    LEFT JOIN anulacion_pago a ON a.id = o.id
    LEFT JOIN operacion original ON original.id = a.pago_id
    LEFT JOIN usuario uv ON uv.id = COALESCE(l.vendedor_id,original.usuario_id,o.usuario_id)
    WHERE o.id = p_operacion_id;
END$$

-- Bloqueo: vendedor antes que cliente.
CREATE PROCEDURE sp_registrar_entrega(
    IN p_actor_id BIGINT UNSIGNED, IN p_cliente_id BIGINT UNSIGNED,
    IN p_modalidad VARCHAR(10), IN p_detalles JSON, IN p_vencimiento DATE
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_lock BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_cliente_activo BOOLEAN DEFAULT FALSE;
    DECLARE v_actor_activo BOOLEAN DEFAULT FALSE;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT;
    DECLARE v_producto_id BIGINT UNSIGNED;
    DECLARE v_producto_nombre VARCHAR(150);
    DECLARE v_unidad VARCHAR(30);
    DECLARE v_producto_activo BOOLEAN;
    DECLARE v_item JSON;
    DECLARE v_cantidad DECIMAL(30,9);
    DECLARE v_precio DECIMAL(30,9);
    DECLARE v_subtotal DECIMAL(30,2);
    DECLARE v_total DECIMAL(30,2) DEFAULT 0;
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_nuevo DECIMAL(15,2);
    DECLARE v_entrega BIGINT UNSIGNED;
    DECLARE v_pago BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_detalle_constancia JSON DEFAULT (JSON_ARRAY());
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    CALL sp__validar_actor(p_actor_id, FALSE);
    SELECT id, activo INTO v_lock, v_actor_activo FROM usuario WHERE id = p_actor_id FOR UPDATE;
    IF NOT v_actor_activo THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor inactivo'; END IF;
    SELECT id, activo INTO v_lock, v_cliente_activo FROM cliente WHERE id = p_cliente_id FOR UPDATE;
    IF NOT v_cliente_activo OR NOT EXISTS (SELECT 1 FROM ubicacion_cliente WHERE cliente_id = p_cliente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente inexistente, inactivo o sin ubicacion';
    END IF;
    IF p_modalidad IS NULL OR BINARY p_modalidad NOT IN ('CREDITO','CONTADO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Modalidad debe ser CREDITO o CONTADO';
    END IF;
    IF p_modalidad = 'CONTADO' AND p_vencimiento IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Entrega al contado no admite vencimiento de credito';
    END IF;
    IF p_detalles IS NULL OR JSON_TYPE(p_detalles) <> 'ARRAY' OR JSON_LENGTH(p_detalles) NOT BETWEEN 1 AND 200 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles debe ser un arreglo de 1 a 200 renglones';
    END IF;
    SET v_n = JSON_LENGTH(p_detalles);
    SELECT saldo INTO v_saldo FROM v_saldos_clientes WHERE cliente_id = p_cliente_id;

    -- Validar antes de crear la operación.
    WHILE v_i < v_n DO
        SET v_item = JSON_EXTRACT(p_detalles, CONCAT('$[',v_i,']'));
        IF JSON_TYPE(v_item) <> 'OBJECT'
           OR COALESCE(JSON_TYPE(JSON_EXTRACT(v_item,'$.producto_id')),'NULL') <> 'INTEGER'
           OR COALESCE(JSON_TYPE(JSON_EXTRACT(v_item,'$.cantidad')),'NULL') NOT IN ('INTEGER','DOUBLE','DECIMAL')
           OR COALESCE(JSON_TYPE(JSON_EXTRACT(v_item,'$.precio_unitario')),'NULL') NOT IN ('INTEGER','DOUBLE','DECIMAL') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Renglon requiere producto_id entero, cantidad y precio numericos';
        END IF;
        IF CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.producto_id')) AS DECIMAL(30,0)) <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto debe ser un identificador positivo';
        END IF;
        SET v_producto_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.producto_id')) AS UNSIGNED);
        SET v_cantidad = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.cantidad')) AS DECIMAL(30,9));
        SET v_precio = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.precio_unitario')) AS DECIMAL(30,9));
        IF v_cantidad <= 0 OR v_cantidad > 999999999.999 OR v_cantidad <> ROUND(v_cantidad,3)
           OR v_precio <= 0 OR v_precio > 99999999999.99 OR v_precio <> ROUND(v_precio,2) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cantidad o precio invalido: cantidad 3 decimales, precio 2 decimales';
        END IF;
        SET v_producto_activo = FALSE;
        SELECT activo INTO v_producto_activo FROM producto WHERE id = v_producto_id FOR SHARE;
        IF NOT v_producto_activo THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto inexistente o inactivo'; END IF;
        SET v_subtotal = ROUND(v_cantidad * v_precio, 2);
        IF v_subtotal <= 0 OR v_subtotal > 99999999999.99 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Subtotal fuera de rango monetario';
        END IF;
        SET v_total = v_total + v_subtotal;
        SET v_i = v_i + 1;
    END WHILE;
    IF v_total > 99999999999.99 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total fuera de rango monetario'; END IF;
    SET v_nuevo = v_saldo + IF(p_modalidad = 'CREDITO', v_total, 0);
    INSERT INTO operacion (folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo)
    VALUES (UUID(),IF(p_modalidad = 'CREDITO','ENTREGA_CREDITO','ENTREGA_CONTADO'),p_actor_id,p_cliente_id,v_total,v_saldo,v_nuevo);
    SET v_entrega = LAST_INSERT_ID();
    INSERT INTO entrega (id,modalidad) VALUES (v_entrega,p_modalidad);
    SET v_i = 0;
    WHILE v_i < v_n DO
        SET v_item = JSON_EXTRACT(p_detalles, CONCAT('$[',v_i,']'));
        SET v_producto_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.producto_id')) AS UNSIGNED);
        SET v_cantidad = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.cantidad')) AS DECIMAL(30,9));
        SET v_precio = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_item,'$.precio_unitario')) AS DECIMAL(30,9));
        SELECT nombre, unidad INTO v_producto_nombre, v_unidad FROM producto WHERE id = v_producto_id;
        INSERT INTO entrega_detalle (entrega_id,renglon,producto_id,producto_nombre,unidad,cantidad,precio_unitario)
        VALUES (v_entrega,v_i+1,v_producto_id,v_producto_nombre,v_unidad,v_cantidad,v_precio);
        SET v_detalle_constancia = JSON_ARRAY_APPEND(v_detalle_constancia,'$',
            JSON_OBJECT('producto',v_producto_nombre,'unidad',v_unidad,'cantidad',v_cantidad,
                        'precio_unitario',v_precio,'subtotal',ROUND(v_cantidad*v_precio,2)));
        SET v_i = v_i + 1;
    END WHILE;
    IF p_modalidad = 'CREDITO' THEN
        INSERT INTO credito (entrega_id,vencimiento) VALUES (v_entrega,p_vencimiento);
    ELSE
        INSERT INTO operacion (folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo)
        VALUES (UUID(),'PAGO_CONTADO',p_actor_id,p_cliente_id,v_total,v_saldo,v_saldo);
        SET v_pago = LAST_INSERT_ID();
        INSERT INTO pago (id,origen,entrega_id) VALUES (v_pago,'CONTADO',v_entrega);
        CALL sp__emitir_constancia(v_pago,JSON_OBJECT('concepto','Pago de entrega al contado','entrega_id',v_entrega,'producto',v_detalle_constancia));
        INSERT INTO auditoria (actor_id,accion,entidad,entidad_id,detalle,usuario_bd)
        VALUES (p_actor_id,'REGISTRAR_PAGO_CONTADO','pago',v_pago,JSON_OBJECT('entrega_id',v_entrega,'monto',v_total),USER());
    END IF;
    CALL sp__emitir_constancia(v_entrega,JSON_OBJECT('producto',v_detalle_constancia,'vencimiento',p_vencimiento));
    INSERT INTO auditoria (actor_id,accion,entidad,entidad_id,detalle,usuario_bd)
    VALUES (p_actor_id,'REGISTRAR_ENTREGA','entrega',v_entrega,JSON_OBJECT('modalidad',p_modalidad,'monto',v_total,'saldo_anterior',v_saldo,'saldo_nuevo',v_nuevo),USER());
    COMMIT;
    SELECT v_entrega AS entrega_id, v_pago AS pago_id, o.folio, o.saldo_anterior, o.saldo_nuevo, c.token_publico
    FROM operacion o JOIN constancia c ON c.operacion_id = o.id WHERE o.id = v_entrega;
END$$

CREATE PROCEDURE sp_registrar_pago(
    IN p_actor_id BIGINT UNSIGNED, IN p_cliente_id BIGINT UNSIGNED, IN p_monto DECIMAL(18,6)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_lock BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_activo BOOLEAN DEFAULT FALSE;
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_pago BIGINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    CALL sp__validar_actor(p_actor_id,FALSE);
    SELECT id, activo INTO v_lock, v_activo FROM usuario WHERE id = p_actor_id FOR UPDATE;
    IF NOT v_activo THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor inactivo'; END IF;
    SET v_activo = FALSE;
    SELECT id, activo INTO v_lock, v_activo FROM cliente WHERE id = p_cliente_id FOR UPDATE;
    IF NOT v_activo OR NOT EXISTS (SELECT 1 FROM ubicacion_cliente WHERE cliente_id = p_cliente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente inexistente, inactivo o sin ubicacion';
    END IF;
    IF p_monto IS NULL OR p_monto <= 0 OR p_monto > 99999999999.99 OR p_monto <> ROUND(p_monto,2) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago debe ser positivo, dentro de rango y con maximo 2 decimales';
    END IF;
    SELECT saldo INTO v_saldo FROM v_saldos_clientes WHERE cliente_id = p_cliente_id;
    IF p_monto > v_saldo THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago supera el saldo pendiente'; END IF;
    INSERT INTO operacion (folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo)
    VALUES (UUID(),'PAGO_ABONO',p_actor_id,p_cliente_id,p_monto,v_saldo,v_saldo-p_monto);
    SET v_pago = LAST_INSERT_ID();
    INSERT INTO pago (id,origen,entrega_id) VALUES (v_pago,'ABONO',NULL);
    CALL sp__emitir_constancia(v_pago,JSON_OBJECT('concepto','Abono a saldo del cliente','medio','EFECTIVO'));
    INSERT INTO auditoria (actor_id,accion,entidad,entidad_id,detalle,usuario_bd)
    VALUES (p_actor_id,'REGISTRAR_ABONO','pago',v_pago,JSON_OBJECT('monto',p_monto,'saldo_anterior',v_saldo,'saldo_nuevo',v_saldo-p_monto),USER());
    COMMIT;
    SELECT v_pago AS pago_id,o.folio,o.saldo_anterior,o.saldo_nuevo,c.token_publico
    FROM operacion o JOIN constancia c ON c.operacion_id = o.id WHERE o.id = v_pago;
END$$

CREATE PROCEDURE sp_confirmar_liquidacion(
    IN p_actor_id BIGINT UNSIGNED, IN p_vendedor_id BIGINT UNSIGNED, IN p_pago_ids JSON
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_lock BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT;
    DECLARE v_pago BIGINT UNSIGNED;
    DECLARE v_vendedor BIGINT UNSIGNED;
    DECLARE v_monto DECIMAL(13,2);
    DECLARE v_total DECIMAL(30,2) DEFAULT 0;
    DECLARE v_liquidacion BIGINT UNSIGNED;
    DECLARE v_vendedor_nombre VARCHAR(150);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    CALL sp__validar_actor(p_actor_id,TRUE);
    -- Permite liquidar efectivo histórico.
    SELECT id,nombre INTO v_lock,v_vendedor_nombre FROM usuario WHERE id = p_vendedor_id FOR UPDATE;
    IF v_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vendedor inexistente'; END IF;
    IF p_pago_ids IS NULL OR JSON_TYPE(p_pago_ids) <> 'ARRAY' OR JSON_LENGTH(p_pago_ids) NOT BETWEEN 1 AND 1000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Liquidacion requiere arreglo de 1 a 1000 pago';
    END IF;
    SET v_n = JSON_LENGTH(p_pago_ids);
    WHILE v_i < v_n DO
        IF JSON_TYPE(JSON_EXTRACT(p_pago_ids,CONCAT('$[',v_i,']'))) <> 'INTEGER'
           OR CAST(JSON_UNQUOTE(JSON_EXTRACT(p_pago_ids,CONCAT('$[',v_i,']'))) AS DECIMAL(30,0)) <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Identificador de pago debe ser entero positivo';
        END IF;
        SET v_pago = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_pago_ids,CONCAT('$[',v_i,']'))) AS UNSIGNED);
        SET v_vendedor = NULL;
        SELECT o.usuario_id,o.monto INTO v_vendedor,v_monto
        FROM pago p JOIN operacion o ON o.id = p.id WHERE p.id = v_pago FOR UPDATE;
        IF v_vendedor IS NULL OR v_vendedor <> p_vendedor_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago inexistente o pertenece a otro vendedor';
        END IF;
        IF EXISTS (SELECT 1 FROM anulacion_pago WHERE pago_id = v_pago)
           OR EXISTS (SELECT 1 FROM liquidacion_pago WHERE pago_id = v_pago) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago anulado o previamente liquidado';
        END IF;
        SET v_total = v_total + v_monto;
        SET v_i = v_i + 1;
    END WHILE;
    IF v_total > 99999999999.99 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Liquidacion fuera de rango monetario'; END IF;
    IF (SELECT COUNT(DISTINCT j.pago_id) FROM JSON_TABLE(p_pago_ids,'$[*]' COLUMNS(pago_id BIGINT UNSIGNED PATH '$' ERROR ON EMPTY ERROR ON ERROR)) j) <> v_n THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite repetir un pago en la liquidacion';
    END IF;
    INSERT INTO operacion (folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo)
    VALUES (UUID(),'LIQUIDACION',p_actor_id,NULL,v_total,NULL,NULL);
    SET v_liquidacion = LAST_INSERT_ID();
    INSERT INTO liquidacion (id,vendedor_id) VALUES (v_liquidacion,p_vendedor_id);
    INSERT INTO liquidacion_pago (liquidacion_id,pago_id)
    SELECT v_liquidacion,j.pago_id FROM JSON_TABLE(p_pago_ids,'$[*]' COLUMNS(pago_id BIGINT UNSIGNED PATH '$' ERROR ON EMPTY ERROR ON ERROR)) j;
    CALL sp__emitir_constancia(v_liquidacion,JSON_OBJECT('concepto','Efectivo recibido y confirmado por administrador','vendedor',v_vendedor_nombre,'pago_ids',p_pago_ids));
    INSERT INTO auditoria (actor_id,accion,entidad,entidad_id,detalle,usuario_bd)
    VALUES (p_actor_id,'CONFIRMAR_LIQUIDACION','liquidacion',v_liquidacion,JSON_OBJECT('vendedor_id',p_vendedor_id,'pago_ids',p_pago_ids,'monto',v_total),USER());
    COMMIT;
    SELECT v_liquidacion AS liquidacion_id,o.folio,o.monto,c.token_publico
    FROM operacion o JOIN constancia c ON c.operacion_id = o.id WHERE o.id = v_liquidacion;
END$$

CREATE PROCEDURE sp_anular_pago(
    IN p_actor_id BIGINT UNSIGNED, IN p_pago_id BIGINT UNSIGNED,
    IN p_motivo VARCHAR(500), IN p_evidencia VARCHAR(1000)
)
SQL SECURITY DEFINER
MODIFIES SQL DATA
BEGIN
    DECLARE v_lock BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_vendedor BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_cliente BIGINT UNSIGNED;
    DECLARE v_monto DECIMAL(13,2);
    DECLARE v_origen VARCHAR(10);
    DECLARE v_saldo DECIMAL(15,2);
    DECLARE v_anulacion BIGINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    CALL sp__validar_actor(p_actor_id,TRUE);
    IF COALESCE(CHAR_LENGTH(TRIM(p_motivo)),0) = 0 OR COALESCE(CHAR_LENGTH(TRIM(p_evidencia)),0) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anulacion requiere motivo y evidencia';
    END IF;
    SELECT o.usuario_id,o.cliente_id,o.monto,p.origen INTO v_vendedor,v_cliente,v_monto,v_origen
    FROM pago p JOIN operacion o ON o.id = p.id WHERE p.id = p_pago_id;
    IF v_vendedor IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago inexistente'; END IF;
    SELECT id INTO v_lock FROM usuario WHERE id = v_vendedor FOR UPDATE;
    SELECT id INTO v_lock FROM cliente WHERE id = v_cliente FOR UPDATE;
    SELECT id INTO v_lock FROM pago WHERE id = p_pago_id FOR UPDATE;
    IF EXISTS (SELECT 1 FROM anulacion_pago WHERE pago_id = p_pago_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago ya anulado';
    END IF;
    IF EXISTS (SELECT 1 FROM liquidacion_pago WHERE pago_id = p_pago_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago liquidado: requiere flujo compensatorio pendiente de definicion';
    END IF;
    IF v_origen = 'CONTADO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago contado: requiere correccion conjunta de entrega pendiente de definicion';
    END IF;
    SELECT saldo INTO v_saldo FROM v_saldos_clientes WHERE cliente_id = v_cliente;
    INSERT INTO operacion (folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo)
    VALUES (UUID(),'ANULACION_PAGO',p_actor_id,v_cliente,v_monto,v_saldo,v_saldo+v_monto);
    SET v_anulacion = LAST_INSERT_ID();
    INSERT INTO anulacion_pago (id,pago_id,motivo,evidencia) VALUES (v_anulacion,p_pago_id,TRIM(p_motivo),TRIM(p_evidencia));
    CALL sp__emitir_constancia(v_anulacion,JSON_OBJECT('concepto','Anulacion administrativa de abono','pago_id',p_pago_id));
    INSERT INTO auditoria (actor_id,accion,entidad,entidad_id,detalle,usuario_bd)
    VALUES (p_actor_id,'ANULAR_PAGO','anulacion_pago',v_anulacion,
            JSON_OBJECT('pago_id',p_pago_id,'vendedor_id',v_vendedor,'motivo',TRIM(p_motivo),'evidencia',TRIM(p_evidencia),
                        'monto',v_monto,'saldo_anterior',v_saldo,'saldo_nuevo',v_saldo+v_monto),USER());
    COMMIT;
    SELECT v_anulacion AS anulacion_id,p_pago_id AS pago_id,o.folio,o.saldo_anterior,o.saldo_nuevo,c.token_publico
    FROM operacion o JOIN constancia c ON c.operacion_id = o.id WHERE o.id = v_anulacion;
END$$

DELIMITER ;

-- Historial inmutable; el DBA administra cambios de esquema.
DELIMITER $$
CREATE TRIGGER tr_operaciones_update
BEFORE UPDATE ON operacion FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'operacion: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_operaciones_delete
BEFORE DELETE ON operacion FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'operacion: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_entregas_update
BEFORE UPDATE ON entrega FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'entrega: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_entregas_delete
BEFORE DELETE ON entrega FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'entrega: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_entregas_detalle_update
BEFORE UPDATE ON entrega_detalle FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'entrega_detalle: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_entregas_detalle_delete
BEFORE DELETE ON entrega_detalle FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'entrega_detalle: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_creditos_update
BEFORE UPDATE ON credito FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'credito: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_creditos_delete
BEFORE DELETE ON credito FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'credito: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_pagos_update
BEFORE UPDATE ON pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pago: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_pagos_delete
BEFORE DELETE ON pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'pago: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_anulaciones_pago_update
BEFORE UPDATE ON anulacion_pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'anulacion_pago: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_anulaciones_pago_delete
BEFORE DELETE ON anulacion_pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'anulacion_pago: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_liquidaciones_update
BEFORE UPDATE ON liquidacion FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'liquidacion: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_liquidaciones_delete
BEFORE DELETE ON liquidacion FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'liquidacion: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_liquidacion_pagos_update
BEFORE UPDATE ON liquidacion_pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'liquidacion_pago: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_liquidacion_pagos_delete
BEFORE DELETE ON liquidacion_pago FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'liquidacion_pago: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_constancias_update
BEFORE UPDATE ON constancia FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'constancia: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_constancias_delete
BEFORE DELETE ON constancia FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'constancia: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_auditoria_update
BEFORE UPDATE ON auditoria FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'auditoria: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_auditoria_delete
BEFORE DELETE ON auditoria FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'auditoria: registro inmutable; no se permite DELETE';
END$$

CREATE TRIGGER tr_variables_analiticas_update
BEFORE UPDATE ON variable_analitica FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'variable_analitica: registro inmutable; no se permite UPDATE';
END$$

CREATE TRIGGER tr_variables_analiticas_delete
BEFORE DELETE ON variable_analitica FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'variable_analitica: registro inmutable; no se permite DELETE';
END$$

DELIMITER ;

CREATE ROLE IF NOT EXISTS 'wl_app_role';
GRANT SELECT ON waterline_one.rol TO 'wl_app_role';
GRANT SELECT ON waterline_one.cliente TO 'wl_app_role';
GRANT SELECT ON waterline_one.ubicacion_cliente TO 'wl_app_role';
GRANT SELECT ON waterline_one.producto TO 'wl_app_role';
GRANT SELECT ON waterline_one.operacion TO 'wl_app_role';
GRANT SELECT ON waterline_one.entrega TO 'wl_app_role';
GRANT SELECT ON waterline_one.entrega_detalle TO 'wl_app_role';
GRANT SELECT ON waterline_one.credito TO 'wl_app_role';
GRANT SELECT ON waterline_one.pago TO 'wl_app_role';
GRANT SELECT ON waterline_one.anulacion_pago TO 'wl_app_role';
GRANT SELECT ON waterline_one.liquidacion TO 'wl_app_role';
GRANT SELECT ON waterline_one.liquidacion_pago TO 'wl_app_role';
GRANT SELECT ON waterline_one.constancia TO 'wl_app_role';
GRANT SELECT ON waterline_one.auditoria TO 'wl_app_role';
GRANT SELECT ON waterline_one.variable_analitica TO 'wl_app_role';
GRANT SELECT ON waterline_one.v_usuarios TO 'wl_app_role';
GRANT SELECT ON waterline_one.v_saldos_clientes TO 'wl_app_role';
GRANT SELECT ON waterline_one.v_estado_pagos TO 'wl_app_role';
GRANT SELECT ON waterline_one.v_efectivo_pendiente TO 'wl_app_role';
GRANT SELECT ON waterline_one.v_constancias_publicas TO 'wl_app_role';
GRANT EXECUTE ON PROCEDURE waterline_one.sp_registrar_entrega TO 'wl_app_role';
GRANT EXECUTE ON PROCEDURE waterline_one.sp_registrar_pago TO 'wl_app_role';
GRANT EXECUTE ON PROCEDURE waterline_one.sp_confirmar_liquidacion TO 'wl_app_role';
GRANT EXECUTE ON PROCEDURE waterline_one.sp_anular_pago TO 'wl_app_role';

-- La aplicación usa un secreto externo, nunca root.
