DROP PROCEDURE IF EXISTS _erp_log_fixed_asset_rebuild;
DELIMITER //
CREATE PROCEDURE `_erp_log_fixed_asset_rebuild`(
    IN `_company_key` INT,
    IN `_item_id` CHAR(36)
)
SQL SECURITY INVOKER
_erp_log_fixed_asset_rebuild: BEGIN
    DECLARE _item_fixed_asset_base_depreciation DECIMAL(20,6) DEFAULT 0.000000;
    DECLARE _item_fixed_asset_depreciation_months INT DEFAULT 0;
    DECLARE _item_fixed_asset_depreciation_monthly DECIMAL(20,6) DEFAULT 0.000000;
    DECLARE _item_fixed_asset_depreciation_start_date DATE DEFAULT NULL;
    DECLARE _item_fixed_asset_depreciation_end_date DATE DEFAULT NULL;

    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF EXISTS (
        SELECT
            erp_log_fixed_asset.id
        FROM erp_log_fixed_asset
        WHERE
            erp_log_fixed_asset.company_key = _company_key AND
            erp_log_fixed_asset.item_id = _item_id AND (
                erp_log_fixed_asset.document_id IS NOT NULL OR
                erp_log_fixed_asset.is_done
            )
        LIMIT 1
    ) THEN
        SELECT 'ERROR: Ya hay depreciaciones contabilizadas';
        LEAVE _erp_log_fixed_asset_rebuild;
    END IF;

    SELECT
        erp_item.item_fixed_asset_base_depreciation,
        erp_item.item_fixed_asset_depreciation_months,
        erp_item.item_fixed_asset_depreciation_monthly,
        erp_item.item_fixed_asset_depreciation_start_date,
        erp_item.item_fixed_asset_depreciation_end_date
    INTO
        _item_fixed_asset_base_depreciation,
        _item_fixed_asset_depreciation_months,
        _item_fixed_asset_depreciation_monthly,
        _item_fixed_asset_depreciation_start_date,
        _item_fixed_asset_depreciation_end_date
    FROM erp_item
    WHERE
        erp_item.company_key = _company_key AND
        erp_item.id = _item_id
    ;

    DELETE FROM erp_log_fixed_asset
    WHERE
        erp_log_fixed_asset.company_key = _company_key AND
        erp_log_fixed_asset.item_id = _item_id AND
        erp_log_fixed_asset.document_id IS NULL AND
        NOT erp_log_fixed_asset.is_done
    ;

    DROP TEMPORARY TABLE IF EXISTS _log_fixed_asset;
    CREATE TEMPORARY TABLE _log_fixed_asset LIKE erp_log_fixed_asset;

    BEGIN
        DECLARE _depreciation_accumulated DECIMAL(20,6) DEFAULT 0.000000;
        DECLARE _depreciation_date DATE DEFAULT _item_fixed_asset_depreciation_start_date;
        DECLARE _depreciation_month_number INT DEFAULT 0;

        depreciation_loop: LOOP
            SET _depreciation_month_number = _depreciation_month_number + 1;

            IF _depreciation_month_number > _item_fixed_asset_depreciation_months THEN LEAVE depreciation_loop; END IF;

            SET _depreciation_accumulated = _depreciation_accumulated + _item_fixed_asset_depreciation_monthly;
            SET _depreciation_date = DATE_ADD(_depreciation_date, INTERVAL 1 MONTH);

            IF _depreciation_month_number = _item_fixed_asset_depreciation_months AND _depreciation_accumulated > _item_fixed_asset_base_depreciation THEN
                SET _item_fixed_asset_depreciation_monthly = _item_fixed_asset_depreciation_monthly + (_item_fixed_asset_base_depreciation - _depreciation_accumulated);
                SET _depreciation_accumulated = _item_fixed_asset_base_depreciation;
            END IF;

            INSERT INTO _log_fixed_asset (
                id,
                company_key,
                item_id,
                is_enabled,
                is_disabled,
                is_revaluation,
                depreciation_monthly,
                depreciation_accumulated,
                depreciation_date
            ) VALUES (
                UUID(),
                _company_key,
                _item_id,
                TRUE,
                FALSE,
                FALSE,
                _item_fixed_asset_depreciation_monthly,
                _depreciation_accumulated,
                _depreciation_date
            );
        END LOOP;
    END;

    INSERT INTO erp_log_fixed_asset (
        id,
        company_key,
        item_id,
        is_enabled,
        is_disabled,
        is_revaluation,
        depreciation_monthly,
        depreciation_accumulated,
        depreciation_date
    )
    SELECT
        _log_fixed_asset.id,
        _log_fixed_asset.company_key,
        _log_fixed_asset.item_id,
        _log_fixed_asset.is_enabled,
        _log_fixed_asset.is_disabled,
        _log_fixed_asset.is_revaluation,
        _log_fixed_asset.depreciation_monthly,
        _log_fixed_asset.depreciation_accumulated,
        _log_fixed_asset.depreciation_date
    FROM _log_fixed_asset
    ;

    DROP TEMPORARY TABLE IF EXISTS _log_fixed_asset;
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END //
DELIMITER ;

CALL _erp_log_fixed_asset_rebuild(0, '00000000-0000-0000-0000-000000000000');
DROP PROCEDURE IF EXISTS _erp_log_fixed_asset_rebuild;
