"""Pruebas aisladas de integridad para MySQL."""

from __future__ import annotations

import concurrent.futures
import csv
from decimal import Decimal
import io
import json
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import threading
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[2]


class MysqlError(RuntimeError):
    def __init__(self, result: subprocess.CompletedProcess[str]):
        self.result = result
        match = re.search(r"ERROR (\d+)", result.stderr)
        self.code = int(match.group(1)) if match else None
        super().__init__(result.stderr.strip() or result.stdout.strip())


class IsolatedDatabase:
    """Proyecto y secretos temporales."""

    def __init__(self, folder: Path):
        self.project = "waterline-one-db-test-" + uuid.uuid4().hex[:12]
        root_secret = folder / "mysql_root_password.txt"
        app_secret = folder / "mysql_app_password.txt"
        for path in (root_secret, app_secret):
            path.write_text(secrets.token_hex(32), encoding="ascii")
        # El tmpfs evita tocar la base local.
        self.override = folder / "compose.test.yaml"
        self.override.write_text(
            "services:\n"
            "  mysql:\n"
            "    ports: !reset []\n"
            "    restart: 'no'\n"
            "    volumes:\n"
            "      - type: tmpfs\n"
            "        target: /var/lib/mysql\n"
            "        tmpfs:\n"
            "          size: 536870912\n"
            "secrets:\n"
            "  mysql_root_password:\n"
            f"    file: {json.dumps(root_secret.as_posix())}\n"
            "  mysql_app_password:\n"
            f"    file: {json.dumps(app_secret.as_posix())}\n",
            encoding="utf-8",
        )
        self.command = [
            "docker", "compose", "--project-name", self.project,
            "--file", str(ROOT / "compose.yaml"),
            "--file", str(self.override),
        ]

    def compose(self, *args: str, timeout: int = 240) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [*self.command, *args], cwd=ROOT, text=True,
            encoding="utf-8", errors="replace", capture_output=True,
            timeout=timeout,
        )

    def start(self) -> None:
        result = self.compose("up", "--detach", "--build", "--wait", "--wait-timeout", "180", timeout=300)
        if result.returncode:
            logs = self.compose("logs", "--tail", "100", "mysql")
            raise RuntimeError(result.stderr + "\n" + logs.stdout + logs.stderr)

    def close(self) -> None:
        # Solo limpia el proyecto temporal.
        if not re.fullmatch(r"waterline-one-db-test-[0-9a-f]{12}", self.project):
            raise RuntimeError("Nombre de proyecto de pruebas inválido; no se elimina nada.")
        result = self.compose("down", "--volumes", "--remove-orphans", timeout=90)
        if result.returncode:
            raise RuntimeError("No se pudo limpiar el proyecto temporal: " + result.stderr)

    def run(self, sql: str, *, root: bool = False) -> list[dict[str, str]]:
        secret = "mysql_root_password" if root else "mysql_app_password"
        user = "root" if root else "waterline_app"
        # El secreto se queda dentro del contenedor.
        script = (
            f'MYSQL_PWD="$(cat /run/secrets/{secret})" '
            f"exec mysql --user={user} --batch --raw "
            "--default-character-set=utf8mb4 waterline_one"
        )
        result = subprocess.run(
            [*self.command, "exec", "--no-TTY", "mysql", "sh", "-ec", script],
            cwd=ROOT, input=sql, text=True, encoding="utf-8", errors="replace",
            capture_output=True, timeout=60,
        )
        if result.returncode:
            raise MysqlError(result)
        return list(csv.DictReader(io.StringIO(result.stdout), delimiter="\t", quoting=csv.QUOTE_NONE))

    def scalar(self, sql: str, *, root: bool = True) -> str:
        rows = self.run(sql, root=root)
        if len(rows) != 1 or len(rows[0]) != 1:
            raise AssertionError(f"Se esperaba una celda, se obtuvo: {rows!r}")
        return next(iter(rows[0].values()))


class FinancialIntegrityTests(unittest.TestCase):
    db: IsolatedDatabase

    @classmethod
    def setUpClass(cls) -> None:
        cls.db.run(
            "INSERT INTO usuario(rol_id,nombre,email,password_hash,activo) VALUES "
            "((SELECT id FROM rol WHERE codigo='administrador'),'ADMIN SINTETICO',"
            "'admin@example.invalid',REPEAT('!',64),TRUE),"
            "((SELECT id FROM rol WHERE codigo='vendedor'),'VENDEDOR SINTETICO A',"
            "'vendedor-a@example.invalid',REPEAT('!',64),TRUE),"
            "((SELECT id FROM rol WHERE codigo='vendedor'),'VENDEDOR SINTETICO B',"
            "'vendedor-b@example.invalid',REPEAT('!',64),TRUE),"
            "((SELECT id FROM rol WHERE codigo='administrador'),'ADMIN INACTIVO SINTETICO',"
            "'inactivo@example.invalid',REPEAT('!',64),FALSE);"
            "INSERT INTO producto(codigo,nombre,precio_referencia) "
            "VALUES('TEST-AGUA','PRODUCTO SINTETICO DE PRUEBA',25.00);",
            root=True,
        )
        cls.admin = int(cls.db.scalar("SELECT id FROM usuario WHERE email='admin@example.invalid'"))
        cls.seller = int(cls.db.scalar("SELECT id FROM usuario WHERE email='vendedor-a@example.invalid'"))
        cls.other_seller = int(cls.db.scalar("SELECT id FROM usuario WHERE email='vendedor-b@example.invalid'"))
        cls.inactive = int(cls.db.scalar("SELECT id FROM usuario WHERE email='inactivo@example.invalid'"))
        cls.product = int(cls.db.scalar("SELECT id FROM producto WHERE codigo='TEST-AGUA'"))

    def setUp(self) -> None:
        name = "CLIENTE SINTETICO " + uuid.uuid4().hex
        self.db.run(
            f"INSERT INTO cliente(nombre,creado_por) VALUES('{name}',{self.admin});"
            "INSERT INTO ubicacion_cliente(cliente_id,direccion) "
            "VALUES(LAST_INSERT_ID(),'REFERENCIA FICTICIA PARA PRUEBAS');",
            root=True,
        )
        self.client = int(self.db.scalar(f"SELECT id FROM cliente WHERE nombre='{name}'"))

    def credit(self, amount: str = "100.00", *, seller: int | None = None,
               mode: str = "CREDITO", client: int | None = None) -> dict[str, str]:
        details = json.dumps([{"producto_id": self.product, "cantidad": 1, "precio_unitario": float(amount)}])
        rows = self.db.run(
            f"CALL sp_registrar_entrega({seller or self.seller},{client or self.client},"
            f"'{mode}','{details}',NULL);"
        )
        self.assertEqual(len(rows), 1, rows)
        return rows[0]

    def pay(self, amount: str, *, seller: int | None = None) -> dict[str, str]:
        rows = self.db.run(f"CALL sp_registrar_pago({seller or self.seller},{self.client},{amount});")
        self.assertEqual(len(rows), 1, rows)
        return rows[0]

    def rejected(self, sql: str, *, root: bool = False,
                 codes: tuple[int, ...] = (1644,)) -> MysqlError:
        with self.assertRaises(MysqlError) as context:
            self.db.run(sql, root=root)
        self.assertIn(context.exception.code, codes, str(context.exception))
        return context.exception

    def balance(self) -> Decimal:
        return Decimal(self.db.scalar(f"SELECT saldo FROM v_saldos_clientes WHERE cliente_id={self.client}"))

    def state(self, payment: int) -> str:
        return self.db.scalar(f"SELECT estado FROM v_estado_pagos WHERE pago_id={payment}")

    def operation_count(self) -> int:
        return int(self.db.scalar("SELECT COUNT(*) FROM operacion"))

    def settle(self, payments: list[int], *, actor: int | None = None,
               seller: int | None = None) -> dict[str, str]:
        rows = self.db.run(
            f"CALL sp_confirmar_liquidacion({actor or self.admin},{seller or self.seller},"
            f"'{json.dumps(payments)}');"
        )
        self.assertEqual(len(rows), 1, rows)
        return rows[0]

    def void(self, payment: int) -> dict[str, str]:
        rows = self.db.run(
            f"CALL sp_anular_pago({self.admin},{payment},"
            "'REGISTRO SINTETICO DUPLICADO','EVIDENCIA SINTETICA DEL CASO DE PRUEBA');"
        )
        self.assertEqual(len(rows), 1, rows)
        return rows[0]

    def test_credit_payment_and_receipts(self) -> None:
        """RN-04/05/06/07: dinero exacto, folio, actor, fecha y comprobante."""
        credit = self.credit()
        self.assertEqual(self.balance(), Decimal("100.00"))
        self.assertEqual(Decimal(credit["saldo_anterior"]), Decimal("0.00"))
        payment = self.pay("30.00")
        self.assertEqual(self.balance(), Decimal("70.00"))
        self.assertEqual(Decimal(payment["saldo_anterior"]), Decimal("100.00"))
        self.assertEqual(Decimal(payment["saldo_nuevo"]), Decimal("70.00"))
        self.assertNotEqual(credit["folio"], payment["folio"])
        self.assertEqual(self.state(int(payment["pago_id"])), "PENDIENTE")
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM operacion o JOIN constancia c ON c.operacion_id=o.id "
            f"WHERE o.cliente_id={self.client} AND o.usuario_id={self.seller} "
            "AND o.fecha IS NOT NULL AND o.folio<>'' AND c.codigo<>'' "
            "AND c.token_publico<>'' AND JSON_VALID(c.contenido)"
        ), "2")

    def test_cash_sale_preserves_existing_debt_and_creates_cash_payment(self) -> None:
        self.credit()
        sale = self.credit("25.00", mode="CONTADO")
        self.assertEqual(self.balance(), Decimal("100.00"))
        payment = int(sale["pago_id"])
        self.assertEqual(self.state(payment), "PENDIENTE")
        self.assertEqual(self.db.scalar(f"SELECT origen FROM pago WHERE id={payment}"), "CONTADO")
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM credito WHERE entrega_id={int(sale['entrega_id'])}"
        ), "0")
        self.settle([payment])
        self.assertEqual(self.state(payment), "LIQUIDADO")

    def test_zero_negative_overpayment_and_fractional_cent_rejected_atomically(self) -> None:
        self.credit()
        before = self.operation_count()
        for amount in ("0", "-1", "100.01", "1.001"):
            with self.subTest(amount=amount):
                self.rejected(f"CALL sp_registrar_pago({self.seller},{self.client},{amount})")
        self.assertEqual(self.operation_count(), before)
        self.assertEqual(self.balance(), Decimal("100.00"))
        self.pay("100.00")
        self.assertEqual(self.balance(), Decimal("0.00"))

    def test_payment_without_credit_is_rejected(self) -> None:
        self.rejected(f"CALL sp_registrar_pago({self.seller},{self.client},1.00)")
        self.assertEqual(self.balance(), Decimal("0.00"))

    def test_late_audit_failure_rolls_back_payment_receipt_and_balance(self) -> None:
        """Falla DESPUÉS de insertar operación y constancia, antes del COMMIT."""
        self.credit()
        before_operations = self.operation_count()
        before_receipts = self.db.scalar("SELECT COUNT(*) FROM constancia")
        self.db.run(
            "CREATE TRIGGER tr_test_forced_audit_failure BEFORE INSERT ON auditoria "
            "FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='FALLO SINTETICO DE AUDITORIA';",
            root=True,
        )
        try:
            error = self.rejected(f"CALL sp_registrar_pago({self.seller},{self.client},10.00)")
            self.assertIn("FALLO SINTETICO DE AUDITORIA", str(error))
        finally:
            self.db.run("DROP TRIGGER tr_test_forced_audit_failure", root=True)
        self.assertEqual(self.operation_count(), before_operations)
        self.assertEqual(self.db.scalar("SELECT COUNT(*) FROM constancia"), before_receipts)
        self.assertEqual(self.balance(), Decimal("100.00"))
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM pago p JOIN operacion o ON o.id=p.id WHERE o.cliente_id={self.client}"
        ), "0")

    def test_invalid_credit_lines_roll_back_whole_operation(self) -> None:
        before = self.operation_count()
        lines = [
            [],
            [{"producto_id": self.product, "cantidad": 0, "precio_unitario": 10}],
            [{"producto_id": self.product, "cantidad": 1, "precio_unitario": -1}],
            [{"producto_id": self.product, "cantidad": 1}],
            [{"producto_id": self.product, "cantidad": 1, "precio_unitario": 10},
             {"producto_id": 999999999, "cantidad": 1, "precio_unitario": 10}],
        ]
        for details in lines:
            with self.subTest(details=details):
                self.rejected(
                    f"CALL sp_registrar_entrega({self.seller},{self.client},'CREDITO',"
                    f"'{json.dumps(details)}',NULL)"
                )
        self.assertEqual(self.operation_count(), before)
        self.assertEqual(self.balance(), Decimal("0.00"))

    def test_settlement_records_specific_payments_and_receiving_administrator(self) -> None:
        self.credit()
        payments = [int(self.pay("15.00")["pago_id"]), int(self.pay("20.00")["pago_id"])]
        settlement = self.settle(payments)
        settlement_id = int(settlement["liquidacion_id"])
        self.assertEqual(Decimal(settlement["monto"]), Decimal("35.00"))
        for payment in payments:
            self.assertEqual(self.state(payment), "LIQUIDADO")
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM liquidacion_pago WHERE liquidacion_id={settlement_id}"
        ), "2")
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM operacion WHERE id={settlement_id} "
            f"AND usuario_id={self.admin} AND fecha IS NOT NULL AND monto=35.00"
        ), "1")
        self.assertGreater(int(self.db.scalar(
            f"SELECT COUNT(*) FROM auditoria WHERE entidad_id={settlement_id} "
            f"AND actor_id={self.admin} AND fecha IS NOT NULL"
        )), 0)
        self.assertEqual(self.balance(), Decimal("65.00"))

    def test_double_settlement_is_rejected(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        self.settle([payment])
        before = self.operation_count()
        self.rejected(f"CALL sp_confirmar_liquidacion({self.admin},{self.seller},'[{payment}]')")
        self.assertEqual(self.operation_count(), before)
        self.assertEqual(self.db.scalar(f"SELECT COUNT(*) FROM liquidacion_pago WHERE pago_id={payment}"), "1")

    def test_settlement_rejects_other_seller_and_invalid_payment_without_partial_changes(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        other_payment = int(self.pay("20.00", seller=self.other_seller)["pago_id"])
        before = self.operation_count()
        for ids in ([payment, other_payment], [payment, 999999999], [payment, payment], []):
            with self.subTest(ids=ids):
                self.rejected(
                    f"CALL sp_confirmar_liquidacion({self.admin},{self.seller},'{json.dumps(ids)}')"
                )
        self.assertEqual(self.operation_count(), before)
        self.assertEqual(self.state(payment), "PENDIENTE")
        self.assertEqual(self.state(other_payment), "PENDIENTE")

    def test_void_preserves_original_payment_and_restores_balance(self) -> None:
        self.credit()
        result = self.pay("30.00")
        payment = int(result["pago_id"])
        original = self.db.run(f"SELECT * FROM operacion WHERE id={payment}", root=True)
        self.void(payment)
        self.assertEqual(self.balance(), Decimal("100.00"))
        self.assertEqual(self.state(payment), "ANULADO")
        self.assertEqual(self.db.run(f"SELECT * FROM operacion WHERE id={payment}", root=True), original)
        self.assertEqual(self.db.scalar(f"SELECT COUNT(*) FROM constancia WHERE operacion_id={payment}"), "1")
        self.assertEqual(self.db.scalar(f"SELECT COUNT(*) FROM anulacion_pago WHERE pago_id={payment}"), "1")
        self.assertEqual(self.db.scalar(
            f"SELECT estado FROM v_constancias_publicas WHERE token_publico='{result['token_publico']}'",
            root=False,
        ), "ANULADO")
        self.rejected(f"CALL sp_confirmar_liquidacion({self.admin},{self.seller},'[{payment}]')")
        self.rejected(f"CALL sp_anular_pago({self.admin},{payment},'OTRA ANULACION','EVIDENCIA FICTICIA')")

    def test_void_requires_reason_and_evidence(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        for reason, evidence in (("", "EVIDENCIA"), ("MOTIVO", ""), ("   ", "EVIDENCIA")):
            with self.subTest(reason=reason, evidence=evidence):
                self.rejected(
                    f"CALL sp_anular_pago({self.admin},{payment},'{reason}','{evidence}')"
                )
        self.assertEqual(self.state(payment), "PENDIENTE")
        self.assertEqual(self.balance(), Decimal("90.00"))

    def test_void_of_settled_and_cash_sale_payments_is_blocked(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        self.settle([payment])
        cash_payment = int(self.credit("25.00", mode="CONTADO")["pago_id"])
        for candidate in (payment, cash_payment):
            with self.subTest(payment=candidate):
                self.rejected(
                    f"CALL sp_anular_pago({self.admin},{candidate},'MOTIVO FICTICIO','EVIDENCIA FICTICIA')"
                )
        self.assertEqual(self.balance(), Decimal("90.00"))

    def test_seller_cannot_void_or_receive_settlements(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        self.rejected(f"CALL sp_confirmar_liquidacion({self.seller},{self.seller},'[{payment}]')")
        self.rejected(
            f"CALL sp_anular_pago({self.seller},{payment},'MOTIVO FICTICIO','EVIDENCIA FICTICIA')"
        )
        self.assertEqual(self.state(payment), "PENDIENTE")

    def test_inactive_and_missing_actors_are_rejected(self) -> None:
        self.credit()
        for actor in (self.inactive, 999999999):
            with self.subTest(actor=actor):
                self.rejected(f"CALL sp_registrar_pago({actor},{self.client},10.00)")
        self.assertEqual(self.balance(), Decimal("100.00"))

    def test_application_has_no_direct_financial_or_role_writes(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        for sql in (
            f"UPDATE operacion SET monto=1 WHERE id={payment}",
            f"DELETE FROM pago WHERE id={payment}",
            f"UPDATE usuario SET rol_id=(SELECT id FROM rol WHERE codigo='administrador') WHERE id={self.seller}",
            "DELETE FROM auditoria",
        ):
            with self.subTest(sql=sql):
                self.rejected(sql, codes=(1142, 1143))
        self.assertEqual(self.balance(), Decimal("90.00"))

    def test_application_cannot_read_password_hashes_or_call_private_helpers(self) -> None:
        self.rejected("SELECT password_hash FROM usuario", codes=(1142, 1143))
        self.rejected(f"CALL sp__validar_actor({self.admin},TRUE)", codes=(1370,))
        self.rejected("CALL sp__emitir_constancia(1,JSON_OBJECT())", codes=(1370,))

    def test_folios_remain_unique_across_all_operation_types_and_voids(self) -> None:
        credit = self.credit()
        payment = self.pay("10.00")
        self.void(int(payment["pago_id"]))
        self.assertEqual(self.db.scalar(
            "SELECT COUNT(*)-COUNT(DISTINCT folio) FROM operacion"
        ), "0")
        self.rejected(
            "INSERT INTO operacion(folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo) "
            f"SELECT folio,tipo,usuario_id,cliente_id,monto,saldo_anterior,saldo_nuevo FROM operacion "
            f"WHERE id={int(payment['pago_id'])}", root=True, codes=(1062,),
        )
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM operacion WHERE folio='{credit['folio']}' OR folio='{payment['folio']}'"
        ), "2")

    def test_receipt_snapshot_survives_customer_changes(self) -> None:
        credit = self.credit()
        operation = int(credit["entrega_id"])
        original = self.db.scalar(f"SELECT contenido FROM constancia WHERE operacion_id={operation}")
        self.db.run(
            f"UPDATE cliente SET nombre='NOMBRE SINTETICO MODIFICADO' WHERE id={self.client}", root=True,
        )
        self.assertEqual(self.db.scalar(f"SELECT contenido FROM constancia WHERE operacion_id={operation}"), original)
        receipt = json.loads(original)
        self.assertEqual(receipt["moneda"], "GTQ")
        for field in ("folio", "fecha_utc", "cliente", "vendedor", "detalle", "monto", "saldo_nuevo"):
            self.assertIn(field, receipt)
            self.assertIsNotNone(receipt[field])

    def test_pending_cash_report_excludes_voided_and_settled_payments(self) -> None:
        self.credit()
        before = Decimal(self.db.scalar(
            f"SELECT COALESCE(SUM(efectivo_pendiente),0.00) FROM v_efectivo_pendiente WHERE vendedor_id={self.seller}"
        ))
        void_payment = int(self.pay("10.00")["pago_id"])
        settled_payment = int(self.pay("20.00")["pago_id"])
        self.pay("15.00")
        self.void(void_payment)
        self.settle([settled_payment])
        after = Decimal(self.db.scalar(
            f"SELECT COALESCE(SUM(efectivo_pendiente),0.00) FROM v_efectivo_pendiente WHERE vendedor_id={self.seller}"
        ))
        self.assertEqual(after - before, Decimal("15.00"))

    def test_financial_history_and_receipts_are_immutable_even_for_direct_sql(self) -> None:
        credit = self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        for sql in (
            f"UPDATE operacion SET monto=1 WHERE id={payment}",
            f"DELETE FROM operacion WHERE id={payment}",
            f"DELETE FROM pago WHERE id={payment}",
            f"UPDATE entrega_detalle SET cantidad=3 WHERE entrega_id={int(credit['entrega_id'])}",
            f"DELETE FROM constancia WHERE operacion_id={payment}",
            f"UPDATE constancia SET codigo='REESCRITO' WHERE operacion_id={payment}",
            f"DELETE FROM auditoria WHERE entidad_id={payment}",
        ):
            with self.subTest(sql=sql):
                self.rejected(sql, root=True)
        self.assertEqual(self.balance(), Decimal("90.00"))

    def test_geography_and_referential_constraints(self) -> None:
        self.rejected(
            f"UPDATE ubicacion_cliente SET latitud=91,longitud=0 WHERE cliente_id={self.client}",
            root=True, codes=(3819, 1644),
        )
        self.rejected(
            f"UPDATE ubicacion_cliente SET latitud=0,longitud=NULL WHERE cliente_id={self.client}",
            root=True, codes=(3819, 1644),
        )
        self.rejected(
            "INSERT INTO ubicacion_cliente(cliente_id,direccion) VALUES(999999999,'FICTICIO')",
            root=True, codes=(1452,),
        )
        self.rejected(
            f"UPDATE ubicacion_cliente SET foto_url='https://example.invalid/foto.jpg' WHERE cliente_id={self.client}",
            root=True, codes=(3819,),
        )
        self.assertEqual(self.db.scalar(f"SELECT telefono IS NULL FROM cliente WHERE id={self.client}"), "1")

    def test_location_may_be_reference_or_complete_coordinates(self) -> None:
        self.db.run(
            f"UPDATE ubicacion_cliente SET direccion=NULL,latitud=14.000000,longitud=-90.000000 "
            f"WHERE cliente_id={self.client}", root=True,
        )
        self.credit()
        self.assertEqual(self.balance(), Decimal("100.00"))

    def test_operation_without_customer_location_is_rejected(self) -> None:
        self.db.run(f"DELETE FROM ubicacion_cliente WHERE cliente_id={self.client}", root=True)
        self.rejected(
            f"CALL sp_registrar_entrega({self.seller},{self.client},'CREDITO',"
            f"'[{{\"producto_id\":{self.product},\"cantidad\":1,\"precio_unitario\":10}}]',NULL)"
        )
        self.assertEqual(self.balance(), Decimal("0.00"))

    def test_innodb_foreign_keys_and_decimal_money(self) -> None:
        self.assertEqual(self.db.scalar(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() "
            "AND table_type='BASE TABLE' AND engine<>'InnoDB'"
        ), "0")
        self.assertEqual(self.db.scalar(
            "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=DATABASE() "
            "AND data_type IN ('float','double')"
        ), "0")
        self.assertGreater(int(self.db.scalar(
            "SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema=DATABASE()"
        )), 10)

    def concurrent_calls(self, sql: str) -> list[list[dict[str, str]] | MysqlError]:
        barrier = threading.Barrier(2)

        def invoke() -> list[dict[str, str]] | MysqlError:
            barrier.wait(timeout=10)
            try:
                return self.db.run(sql)
            except MysqlError as error:
                return error

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            jobs = [pool.submit(invoke) for _ in range(2)]
            return [job.result(timeout=70) for job in jobs]

    def test_concurrent_payments_cannot_overdraw_customer(self) -> None:
        self.credit()
        results = self.concurrent_calls(f"CALL sp_registrar_pago({self.seller},{self.client},60.00)")
        successes = [result for result in results if not isinstance(result, MysqlError)]
        failures = [result for result in results if isinstance(result, MysqlError)]
        self.assertEqual(len(successes), 1, results)
        # Puede fallar por saldo (1644) o bloqueo transitorio (1213).
        # La API debe reintentar 1213.
        self.assertIn(failures[0].code, (1213, 1644), results)
        self.assertEqual(self.balance(), Decimal("40.00"))
        self.assertEqual(self.db.scalar(
            f"SELECT COUNT(*) FROM pago p JOIN operacion o ON o.id=p.id WHERE o.cliente_id={self.client}"
        ), "1")

    def test_concurrent_settlements_cannot_receive_payment_twice(self) -> None:
        self.credit()
        payment = int(self.pay("10.00")["pago_id"])
        results = self.concurrent_calls(
            f"CALL sp_confirmar_liquidacion({self.admin},{self.seller},'[{payment}]')"
        )
        successes = [result for result in results if not isinstance(result, MysqlError)]
        failures = [result for result in results if isinstance(result, MysqlError)]
        self.assertEqual(len(successes), 1, results)
        self.assertEqual([error.code for error in failures], [1644], results)
        self.assertEqual(self.db.scalar(f"SELECT COUNT(*) FROM liquidacion_pago WHERE pago_id={payment}"), "1")
        self.assertEqual(self.state(payment), "LIQUIDADO")


def main() -> int:
    # Datos y secretos temporales.
    with tempfile.TemporaryDirectory(prefix="waterline-db-test-") as folder:
        db = IsolatedDatabase(Path(folder))
        print("Base de pruebas aislada:", db.project, flush=True)
        try:
            db.start()
            FinancialIntegrityTests.db = db
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(FinancialIntegrityTests)
            result = unittest.TextTestRunner(verbosity=2).run(suite)
            return 0 if result.wasSuccessful() else 1
        finally:
            db.close()


if __name__ == "__main__":
    sys.exit(main())
