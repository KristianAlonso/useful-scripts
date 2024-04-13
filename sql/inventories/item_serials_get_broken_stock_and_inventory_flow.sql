DROP PROCEDURE IF EXISTS _erp_item_serials_get_broken_stock_and_inventory_flow;
DELIMITER //
CREATE PROCEDURE `_erp_item_serials_get_broken_stock_and_inventory_flow`(
  IN `_company_key` INT
)
SQL SECURITY INVOKER
_erp_item_serials_get_broken_stock_and_inventory_flow: BEGIN
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DROP TEMPORARY TABLE IF EXISTS _inventory_flow;
  CREATE TEMPORARY TABLE _inventory_flow (
    `idx` INT AUTO_INCREMENT,
    `item_id` CHAR(36) NOT NULL,
    `item_code` VARCHAR(120) NOT NULL,
    `item_name` VARCHAR(120) NOT NULL,
    `item_serial_number` VARCHAR(120) NOT NULL,
    `inventory_incomes` VARCHAR(120) NOT NULL,
    `inventory_outcomes` VARCHAR(120) NOT NULL,
    `expected_stock` VARCHAR(120) NOT NULL,
    `inventory_description` VARCHAR(240) NULL DEFAULT NULL,
    INDEX idx_idx (`idx`)
  );

  BEGIN
    DECLARE _item_serials_with_broken_stock_cursor_has_rows TINYINT(1) DEFAULT TRUE;
    DECLARE _item_serials_with_broken_stock_cursor CURSOR FOR
      SELECT
        erp_item.company_key AS company_key,
        erp_item.id AS item_id,
        erp_item.item_code,
        erp_item.item_name,
        erp_inventory_detail.item_serial_number,
        SUM(IF(erp_inventory_detail.inventory_detail_type = 'IN', erp_inventory_detail.inventory_detail_quantity, 0)) AS inventory_incomes,
        SUM(IF(erp_inventory_detail.inventory_detail_type = 'OT', erp_inventory_detail.inventory_detail_quantity, 0)) AS inventory_outcomes,
        SUM(IF(erp_inventory_detail.inventory_detail_type = 'IN', erp_inventory_detail.inventory_detail_quantity, -erp_inventory_detail.inventory_detail_quantity)) AS expected_stock
      FROM erp_item
      INNER JOIN erp_inventory_detail ON
        erp_inventory_detail.company_key = erp_item.company_key AND
        erp_inventory_detail.item_id = erp_item.id
      INNER JOIN erp_inventory ON
        erp_inventory.company_key = erp_inventory_detail.company_key AND
        erp_inventory.id = erp_inventory_detail.inventory_id
      WHERE
        erp_item.company_key = _company_key AND
        erp_item.item_is_stock AND
        erp_item.item_has_serial AND
        erp_inventory.inventory_status = 'A'
      GROUP BY
        erp_item.id,
        erp_inventory_detail.item_serial_number
      HAVING
        inventory_incomes < inventory_outcomes
    ;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET _item_serials_with_broken_stock_cursor_has_rows = FALSE;

    OPEN _item_serials_with_broken_stock_cursor;
    BEGIN
      DECLARE _company_key VARCHAR(120) DEFAULT NULL;
      DECLARE _item_id CHAR(36) DEFAULT NULL;
      DECLARE _item_code VARCHAR(120) DEFAULT NULL;
      DECLARE _item_name VARCHAR(120) DEFAULT NULL;
      DECLARE _item_serial_number VARCHAR(120) DEFAULT 0.000000;
      DECLARE _inventory_incomes DECIMAL(20,6) DEFAULT 0.000000;
      DECLARE _inventory_outcomes DECIMAL(20,6) DEFAULT 0.000000;
      DECLARE _expected_stock DECIMAL(20,6) DEFAULT 0.000000;

      item_serials_with_broken_stock_cursor_loop: LOOP
        FETCH _item_serials_with_broken_stock_cursor INTO
          _company_key,
          _item_id,
          _item_code,
          _item_name,
          _item_serial_number,
          _inventory_incomes,
          _inventory_outcomes,
          _expected_stock
        ;

        IF NOT _item_serials_with_broken_stock_cursor_has_rows THEN LEAVE item_serials_with_broken_stock_cursor_loop; END IF;

        INSERT INTO _inventory_flow (
          item_id,
          item_code,
          item_name,
          item_serial_number,
          inventory_incomes,
          inventory_outcomes,
          expected_stock
        )
        SELECT
          '',
          _item_code,
          _item_name,
          _item_serial_number,
          _inventory_incomes,
          _inventory_outcomes,
          _expected_stock
        ;

        INSERT INTO _inventory_flow (
          item_id,
          item_code,
          item_name,
          item_serial_number,
          inventory_incomes,
          inventory_outcomes,
          expected_stock,
          inventory_description
        )
        SELECT
            erp_inventory.inventory_type,
            CONCAT_WS(' -> ', warehouse_from.warehouse_name, warehouse_to.warehouse_name),
            IF(erp_inventory_detail.inventory_detail_type = 'IN', 'Entrada', 'Salida'),
            IF(erp_inventory_detail.inventory_detail_type = 'IN', erp_inventory_detail.inventory_detail_quantity, -erp_inventory_detail.inventory_detail_quantity),
            erp_inventory.inventory_created_at,
            IFNULL(erp_inventory.inventory_created_tag, ''),
            '',
            erp_inventory.inventory_description
        FROM erp_inventory_detail
        INNER JOIN erp_inventory ON
            erp_inventory.company_key = erp_inventory_detail.company_key AND
            erp_inventory.id = erp_inventory_detail.inventory_id
        INNER JOIN erp_warehouse warehouse_from ON warehouse_from.id = erp_inventory_detail.warehouse_id
        LEFT OUTER JOIN erp_warehouse warehouse_to ON warehouse_to.id = erp_inventory_detail.warehouse_id_transfer
        WHERE
          erp_inventory_detail.company_key = _company_key AND
          erp_inventory_detail.item_id = _item_id AND
          erp_inventory_detail.item_serial_number = _item_serial_number
        ORDER BY
          erp_inventory_detail.inventory_detail_created_at ASC
        ;
      END LOOP;
    END;
    CLOSE _item_serials_with_broken_stock_cursor;
  END;

  SELECT
    _inventory_flow.idx AS `#`,
    _inventory_flow.item_id AS `Tipo`,
    _inventory_flow.item_code AS `Cód producto`,
    _inventory_flow.item_name AS `Nombre producto`,
    _inventory_flow.item_serial_number AS `Serial`,
    _inventory_flow.inventory_incomes AS `Entradas`,
    _inventory_flow.inventory_outcomes AS `Salidas`,
    _inventory_flow.expected_stock AS `Stock`,
    _inventory_flow.inventory_description AS `Descripción`
  FROM _inventory_flow
  ;

  DROP TEMPORARY TABLE IF EXISTS _inventory_flow;
  SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END //

DELIMITER ;

CALL _erp_item_serials_get_broken_stock_and_inventory_flow(0);
DROP PROCEDURE IF EXISTS _erp_item_serials_get_broken_stock_and_inventory_flow;
