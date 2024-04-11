DELIMITER //

DROP PROCEDURE IF EXISTS `rebuild_erp_biz_consolidated_sales` //
CREATE DEFINER=`rootsa`@`%` PROCEDURE `rebuild_erp_biz_consolidated_sales`(
  IN `_company_key` INT,
  IN `_date_from` DATE
)
LANGUAGE SQL
NOT DETERMINISTIC
CONTAINS SQL
SQL SECURITY INVOKER
COMMENT 'Reconstruye el reporte de ventas'
BEGIN
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DROP TEMPORARY TABLE IF EXISTS _invoices;
  CREATE TEMPORARY TABLE IF NOT EXISTS _invoices
  SELECT
    erp_invoice.id,
    erp_invoice.company_key,
    erp_invoice.branch_id,
    erp_invoice.person_id_seller,
    erp_invoice.biz_document_type_code,
    erp_invoice.biz_document_has_refund,
    erp_invoice.biz_document_refund_ingress,
    erp_invoice.biz_document_refund_discount,
    erp_invoice.biz_document_exchange_rate,
    erp_invoice.biz_document_subtotal,
    erp_invoice.biz_document_discount,
    erp_invoice.biz_document_date,
    erp_invoice.biz_document_year,
    erp_invoice.biz_document_month,
    erp_invoice.biz_document_day
  FROM erp_invoice
  WHERE
    (_company_key IS NULL OR erp_invoice.company_key = _company_key) AND
    (_date_from IS NULL OR erp_invoice.biz_document_year >= YEAR(_date_from)) AND
    (_date_from IS NULL OR erp_invoice.biz_document_month >= MONTH(_date_from)) AND
    erp_invoice.invoice_status != 'Anulada' AND
    erp_invoice.document_mode = 'production' AND (
      erp_invoice.invoice_status_dian != 'Emision' OR (erp_invoice.invoice_status_dian = 'Emision' AND erp_invoice.invoice_state_dian = 'Valida')
    )
  ;

  DROP TEMPORARY TABLE IF EXISTS _invoice_debit_notes;
  CREATE TEMPORARY TABLE IF NOT EXISTS _invoice_debit_notes
  SELECT
    erp_invoice_debit_note.id,
    erp_invoice_debit_note.company_key,
    erp_invoice_debit_note.branch_id,
    erp_invoice_debit_note.person_id_seller,
    erp_invoice_debit_note.biz_document_exchange_rate,
    erp_invoice_debit_note.biz_document_subtotal,
    erp_invoice_debit_note.biz_document_discount,
    erp_invoice_debit_note.biz_document_date,
    erp_invoice_debit_note.biz_document_year,
    erp_invoice_debit_note.biz_document_month,
    erp_invoice_debit_note.biz_document_day
  FROM erp_invoice_debit_note
  WHERE
    (_company_key IS NULL OR erp_invoice_debit_note.company_key = _company_key) AND
    (_date_from IS NULL OR erp_invoice_debit_note.biz_document_year >= YEAR(_date_from)) AND
    (_date_from IS NULL OR erp_invoice_debit_note.biz_document_month >= MONTH(_date_from)) AND
    erp_invoice_debit_note.invoice_debit_note_status != 'Anulada' AND
    erp_invoice_debit_note.document_mode = 'production' AND (
      erp_invoice_debit_note.invoice_debit_note_status_dian != 'Emision' OR (erp_invoice_debit_note.invoice_debit_note_status_dian = 'Emision' AND erp_invoice_debit_note.invoice_debit_note_state_dian = 'Valida')
    )
  ;

  DROP TEMPORARY TABLE IF EXISTS _invoice_credit_notes;
  CREATE TEMPORARY TABLE IF NOT EXISTS _invoice_credit_notes
  SELECT
    erp_invoice_credit_note.id,
    erp_invoice_credit_note.company_key,
    erp_invoice_credit_note.branch_id,
    erp_invoice_credit_note.person_id_seller,
    erp_invoice_credit_note.biz_document_exchange_rate,
    erp_invoice_credit_note.biz_document_subtotal,
    erp_invoice_credit_note.biz_document_discount,
    erp_invoice_credit_note.biz_document_date,
    erp_invoice_credit_note.biz_document_year,
    erp_invoice_credit_note.biz_document_month,
    erp_invoice_credit_note.biz_document_day
  FROM erp_invoice_credit_note
  WHERE
    (_company_key IS NULL OR erp_invoice_credit_note.company_key = _company_key) AND
    (_date_from IS NULL OR erp_invoice_credit_note.biz_document_year >= YEAR(_date_from)) AND
    (_date_from IS NULL OR erp_invoice_credit_note.biz_document_month >= MONTH(_date_from)) AND
    erp_invoice_credit_note.invoice_credit_note_status != 'Anulada' AND
    erp_invoice_credit_note.document_mode = 'production' AND (
      erp_invoice_credit_note.invoice_credit_note_status_dian != 'Emision' OR (erp_invoice_credit_note.invoice_credit_note_status_dian = 'Emision' AND erp_invoice_credit_note.invoice_credit_note_state_dian = 'Valida')
    )
  ;

  /* Reporte de ventas por sucursal */
  REPLACE INTO erp_biz_consolidated_sales (
    id,
    company_key,
    branch_id,
    sales_total,
    sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  )
  SELECT
    UUID() AS id,
    report_data.company_key,
    report_data.branch_id,
    SUM(report_data.sales_total) AS sales_total,
    SUM(report_data.sales_total_refund) AS sales_total_refund,
    report_data.sales_date,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  FROM ((
    SELECT
      _invoices.company_key,
      _invoices.branch_id,
      IF(_invoices.biz_document_type_code = 'INS',
        _invoices.biz_document_subtotal - _invoices.biz_document_discount - IF(_invoices.biz_document_has_refund, 0, _invoices.biz_document_refund_ingress + _invoices.biz_document_refund_discount),
        _invoices.biz_document_subtotal - _invoices.biz_document_discount
      ) * IF(_invoices.biz_document_exchange_rate != 0, _invoices.biz_document_exchange_rate, 1) AS sales_total,
      0.00000000 AS sales_total_refund,
      _invoices.biz_document_date AS sales_date,
      _invoices.biz_document_year AS sales_year,
      _invoices.biz_document_month AS sales_month,
      _invoices.biz_document_day AS sales_day
    FROM _invoices
  ) UNION ALL (
    SELECT
      _invoice_debit_notes.company_key,
      _invoice_debit_notes.branch_id,
      (
        (_invoice_debit_notes.biz_document_subtotal - _invoice_debit_notes.biz_document_discount) *
        IF(_invoice_debit_notes.biz_document_exchange_rate != 0, _invoice_debit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total,
      0.00000000 AS sales_total_refund,
      _invoice_debit_notes.biz_document_date AS sales_date,
      _invoice_debit_notes.biz_document_year AS sales_year,
      _invoice_debit_notes.biz_document_month AS sales_month,
      _invoice_debit_notes.biz_document_day AS sales_day
    FROM _invoice_debit_notes
  ) UNION ALL (
    SELECT
      _invoice_credit_notes.company_key,
      _invoice_credit_notes.branch_id,
      0.00000000 AS sales_total,
      (
        (_invoice_credit_notes.biz_document_subtotal - _invoice_credit_notes.biz_document_discount) *
        IF(_invoice_credit_notes.biz_document_exchange_rate != 0, _invoice_credit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total_refund,
      _invoice_credit_notes.biz_document_date AS sales_date,
      _invoice_credit_notes.biz_document_year AS sales_year,
      _invoice_credit_notes.biz_document_month AS sales_month,
      _invoice_credit_notes.biz_document_day AS sales_day
    FROM _invoice_credit_notes
  )) AS report_data
  GROUP BY
    report_data.company_key,
    report_data.branch_id,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ORDER BY
    report_data.company_key,
    report_data.branch_id,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ;

  /* Reporte de ventas por vendedor */
  REPLACE INTO erp_biz_consolidated_sales_seller (
    id,
    company_key,
    person_id_seller,
    sales_total,
    sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  )
  SELECT
    UUID() AS id,
    report_data.company_key,
    IFNULL(report_data.person_id_seller, '00000000-0000-0000-0000-000000000000') AS person_id_seller,
    SUM(report_data.sales_total) AS sales_total,
    SUM(report_data.sales_total_refund) AS sales_total_refund,
    report_data.sales_date,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  FROM ((
    SELECT
      _invoices.company_key,
      _invoices.person_id_seller,
      IF(_invoices.biz_document_type_code = 'INS',
        _invoices.biz_document_subtotal - _invoices.biz_document_discount - IF(_invoices.biz_document_has_refund, 0, _invoices.biz_document_refund_ingress + _invoices.biz_document_refund_discount),
        _invoices.biz_document_subtotal - _invoices.biz_document_discount
      ) * IF(_invoices.biz_document_exchange_rate != 0, _invoices.biz_document_exchange_rate, 1) AS sales_total,
      0.00000000 AS sales_total_refund,
      _invoices.biz_document_date AS sales_date,
      _invoices.biz_document_year AS sales_year,
      _invoices.biz_document_month AS sales_month,
      _invoices.biz_document_day AS sales_day
    FROM _invoices
  ) UNION ALL (
    SELECT
      _invoice_debit_notes.company_key,
      _invoice_debit_notes.person_id_seller,
      (
        (_invoice_debit_notes.biz_document_subtotal - _invoice_debit_notes.biz_document_discount) *
        IF(_invoice_debit_notes.biz_document_exchange_rate != 0, _invoice_debit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total,
      0.00000000 AS sales_total_refund,
      _invoice_debit_notes.biz_document_date AS sales_date,
      _invoice_debit_notes.biz_document_year AS sales_year,
      _invoice_debit_notes.biz_document_month AS sales_month,
      _invoice_debit_notes.biz_document_day AS sales_day
    FROM _invoice_debit_notes
  ) UNION ALL (
    SELECT
      _invoice_credit_notes.company_key,
      _invoice_credit_notes.person_id_seller,
      0.00000000 AS sales_total,
      (
        (_invoice_credit_notes.biz_document_subtotal - _invoice_credit_notes.biz_document_discount) *
        IF(_invoice_credit_notes.biz_document_exchange_rate != 0, _invoice_credit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total_refund,
      _invoice_credit_notes.biz_document_date AS sales_date,
      _invoice_credit_notes.biz_document_year AS sales_year,
      _invoice_credit_notes.biz_document_month AS sales_month,
      _invoice_credit_notes.biz_document_day AS sales_day
    FROM _invoice_credit_notes
  )) AS report_data
  GROUP BY
    report_data.company_key,
    report_data.person_id_seller,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ORDER BY
    report_data.company_key,
    report_data.person_id_seller,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ;

  /* Reporte de ventas por item */
  REPLACE INTO erp_biz_consolidated_sales_item (
    id,
    company_key,
    branch_id,
    item_id,
    sales_total,
    sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  )
  SELECT
    UUID() AS id,
    report_data.company_key,
    report_data.branch_id,
    report_data.item_id,
    SUM(report_data.sales_total) AS sales_total,
    SUM(report_data.sales_total_refund) AS sales_total_refund,
    report_data.sales_date,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  FROM ((
    SELECT
      erp_invoice_detail.company_key,
      _invoices.branch_id,
      erp_invoice_detail.item_id,
      IF(
        erp_invoice_detail.biz_document_detail_is_present, 0.00000000,
        IF(erp_invoice_detail.biz_document_type_code = 'INS',
          (erp_invoice_detail.biz_document_detail_quantity - IF(_invoices.biz_document_has_refund, 0, erp_invoice_detail.biz_document_detail_quantity_refund)) * erp_invoice_detail.biz_document_detail_unit_value,
          erp_invoice_detail.biz_document_detail_quantity * erp_invoice_detail.biz_document_detail_unit_value
        ) * IF(_invoices.biz_document_exchange_rate != 0, _invoices.biz_document_exchange_rate, 1)
      ) AS sales_total,
      0.00000000 AS sales_total_refund,
      erp_invoice_detail.biz_document_detail_date AS sales_date,
      erp_invoice_detail.biz_document_detail_year AS sales_year,
      erp_invoice_detail.biz_document_detail_month AS sales_month,
      erp_invoice_detail.biz_document_detail_day AS sales_day
    FROM erp_invoice_detail
    INNER JOIN _invoices ON _invoices.id = erp_invoice_detail.biz_document_id
    WHERE
      (_company_key IS NULL OR erp_invoice_detail.company_key = _company_key) AND
      (_date_from IS NULL OR erp_invoice_detail.biz_document_detail_year >= YEAR(_date_from)) AND
      (_date_from IS NULL OR erp_invoice_detail.biz_document_detail_month >= MONTH(_date_from)) AND
      NOT erp_invoice_detail.biz_document_detail_is_present
    ) UNION ALL (
    SELECT
      erp_invoice_debit_note_detail.company_key,
      _invoice_debit_notes.branch_id,
      erp_invoice_debit_note_detail.item_id,
      IF(
        erp_invoice_debit_note_detail.biz_document_detail_is_present, 0.00000000,
        erp_invoice_debit_note_detail.biz_document_detail_quantity *
        erp_invoice_debit_note_detail.biz_document_detail_unit_value *
        IF(_invoice_debit_notes.biz_document_exchange_rate != 0, _invoice_debit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total,
      0.00000000 AS sales_total_refund,
      erp_invoice_debit_note_detail.biz_document_detail_date AS sales_date,
      erp_invoice_debit_note_detail.biz_document_detail_year AS sales_year,
      erp_invoice_debit_note_detail.biz_document_detail_month AS sales_month,
      erp_invoice_debit_note_detail.biz_document_detail_day AS sales_day
    FROM erp_invoice_debit_note_detail
    INNER JOIN _invoice_debit_notes ON _invoice_debit_notes.id = erp_invoice_debit_note_detail.biz_document_id
    WHERE
      (_company_key IS NULL OR erp_invoice_debit_note_detail.company_key = _company_key) AND
      (_date_from IS NULL OR erp_invoice_debit_note_detail.biz_document_detail_year >= YEAR(_date_from)) AND
      (_date_from IS NULL OR erp_invoice_debit_note_detail.biz_document_detail_month >= MONTH(_date_from)) AND
      NOT erp_invoice_debit_note_detail.biz_document_detail_is_present
    ) UNION ALL (
    SELECT
      erp_invoice_credit_note_detail.company_key,
      _invoice_credit_notes.branch_id,
      erp_invoice_credit_note_detail.item_id,
      0.00000000 AS sales_total,
      IF(
        erp_invoice_credit_note_detail.biz_document_detail_is_present, 0.00000000,
        erp_invoice_credit_note_detail.biz_document_detail_quantity *
        erp_invoice_credit_note_detail.biz_document_detail_unit_value *
        IF(_invoice_credit_notes.biz_document_exchange_rate != 0, _invoice_credit_notes.biz_document_exchange_rate, 1)
      ) AS sales_total_refund,
      erp_invoice_credit_note_detail.biz_document_detail_date AS sales_date,
      erp_invoice_credit_note_detail.biz_document_detail_year AS sales_year,
      erp_invoice_credit_note_detail.biz_document_detail_month AS sales_month,
      erp_invoice_credit_note_detail.biz_document_detail_day AS sales_day
    FROM erp_invoice_credit_note_detail
    INNER JOIN _invoice_credit_notes ON _invoice_credit_notes.id = erp_invoice_credit_note_detail.biz_document_id
    WHERE
      (_company_key IS NULL OR erp_invoice_credit_note_detail.company_key = _company_key) AND
      (_date_from IS NULL OR erp_invoice_credit_note_detail.biz_document_detail_year >= YEAR(_date_from)) AND
      (_date_from IS NULL OR erp_invoice_credit_note_detail.biz_document_detail_month >= MONTH(_date_from)) AND
      NOT erp_invoice_credit_note_detail.biz_document_detail_is_present
  )) AS report_data
  GROUP BY
    report_data.company_key,
    report_data.branch_id,
    report_data.item_id,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ORDER BY
    report_data.company_key,
    report_data.branch_id,
    report_data.item_id,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  ;

  DROP TEMPORARY TABLE IF EXISTS _invoices;
  DROP TEMPORARY TABLE IF EXISTS _invoice_debit_notes;
  DROP TEMPORARY TABLE IF EXISTS _invoice_credit_notes;

  SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END //

CALL `rebuild_erp_biz_consolidated_sales`(@_company_key, '2023-01-01') //
