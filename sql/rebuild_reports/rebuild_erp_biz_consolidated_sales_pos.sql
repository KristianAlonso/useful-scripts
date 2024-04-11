DELIMITER //

DROP PROCEDURE IF EXISTS `rebuild_erp_biz_consolidated_sales_pos` //
CREATE DEFINER=`rootsa`@`%` PROCEDURE `rebuild_erp_biz_consolidated_sales_pos`(
  IN _company_key INT,
  IN _date_from DATE
)
LANGUAGE SQL
NOT DETERMINISTIC
CONTAINS SQL
SQL SECURITY INVOKER
COMMENT 'Reconstruye el reporte de ventas POS'
BEGIN
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

  DROP TEMPORARY TABLE IF EXISTS _pos_invoices;
  CREATE TEMPORARY TABLE IF NOT EXISTS _pos_invoices
  SELECT
    erp_pos_invoice.id,
    erp_pos_invoice.company_key,
    erp_pos_invoice.branch_id,
    erp_pos_invoice.person_id_seller,
    erp_pos_invoice.invoice_subtotal,
    erp_pos_invoice.invoice_discount,
    erp_pos_invoice.invoice_date,
    erp_pos_invoice.invoice_year,
    erp_pos_invoice.invoice_month,
    erp_pos_invoice.invoice_day
  FROM erp_pos_invoice
  WHERE
    (_company_key IS NULL OR erp_pos_invoice.company_key = _company_key) AND
    (_date_from IS NULL OR erp_pos_invoice.invoice_year >= YEAR(_date_from)) AND
    (_date_from IS NULL OR erp_pos_invoice.invoice_month >= MONTH(_date_from)) AND
    erp_pos_invoice.invoice_type = 'IN' AND
    erp_pos_invoice.invoice_status NOT IN ('OP', 'Parked') AND
    erp_pos_invoice.document_mode = 'production' AND (
      erp_pos_invoice.invoice_status_dian != 'Emision' OR (erp_pos_invoice.invoice_status_dian = 'Emision' AND erp_pos_invoice.invoice_state_dian = 'Valida')
    )
  ;

  DROP TEMPORARY TABLE IF EXISTS _pos_credit_notes;
  CREATE TEMPORARY TABLE IF NOT EXISTS _pos_credit_notes
  SELECT
    erp_pos_credit_notes.id,
    erp_pos_credit_notes.company_key,
    erp_pos_credit_notes.branch_id,
    erp_pos_credit_notes.person_id_seller,
    erp_pos_credit_notes.credit_note_subtotal,
    erp_pos_credit_notes.credit_note_discount,
    erp_pos_credit_notes.credit_note_date,
    erp_pos_credit_notes.credit_note_year,
    erp_pos_credit_notes.credit_note_month,
    erp_pos_credit_notes.credit_note_day
  FROM erp_pos_credit_notes
  WHERE
    (_company_key IS NULL OR erp_pos_credit_notes.company_key = _company_key) AND
    (_date_from IS NULL OR erp_pos_credit_notes.credit_note_year >= YEAR(_date_from)) AND
    (_date_from IS NULL OR erp_pos_credit_notes.credit_note_month >= MONTH(_date_from)) AND
    erp_pos_credit_notes.document_mode = 'production' AND (
      erp_pos_credit_notes.credit_note_status_dian != 'Emision' OR (erp_pos_credit_notes.credit_note_status_dian = 'Emision' AND erp_pos_credit_notes.credit_note_state_dian = 'Valida')
    )
  ;

  /* Reporte de ventas por sucursal */
  REPLACE INTO erp_biz_consolidated_sales_pos (
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
      _pos_invoices.company_key,
      _pos_invoices.branch_id,
      _pos_invoices.invoice_subtotal AS sales_total,
      0.00000000 AS sales_total_refund,
      _pos_invoices.invoice_date AS sales_date,
      _pos_invoices.invoice_year AS sales_year,
      _pos_invoices.invoice_month AS sales_month,
      _pos_invoices.invoice_day AS sales_day
    FROM _pos_invoices
  ) UNION ALL (
    SELECT
      _pos_credit_notes.company_key,
      _pos_credit_notes.branch_id,
      0.00000000 AS sales_total,
      _pos_credit_notes.credit_note_subtotal AS sales_total_refund,
      _pos_credit_notes.credit_note_date AS sales_date,
      _pos_credit_notes.credit_note_year AS sales_year,
      _pos_credit_notes.credit_note_month AS sales_month,
      _pos_credit_notes.credit_note_day AS sales_day
    FROM _pos_credit_notes
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
  REPLACE INTO erp_biz_consolidated_sales_pos_seller (
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
    report_data.person_id_seller,
    SUM(report_data.sales_total) AS sales_total,
    SUM(report_data.sales_total_refund) AS sales_total_refund,
    report_data.sales_date,
    report_data.sales_year,
    report_data.sales_month,
    report_data.sales_day
  FROM ((
    SELECT
      _pos_invoices.company_key,
      _pos_invoices.person_id_seller,
      _pos_invoices.invoice_subtotal AS sales_total,
      0.00000000 AS sales_total_refund,
      _pos_invoices.invoice_date AS sales_date,
      _pos_invoices.invoice_year AS sales_year,
      _pos_invoices.invoice_month AS sales_month,
      _pos_invoices.invoice_day AS sales_day
    FROM _pos_invoices
    WHERE
      _pos_invoices.person_id_seller IS NOT NULL
  ) UNION ALL (
    SELECT
      _pos_credit_notes.company_key,
      _pos_credit_notes.person_id_seller,
      0.00000000 AS sales_total,
      _pos_credit_notes.credit_note_subtotal AS sales_total_refund,
      _pos_credit_notes.credit_note_date AS sales_date,
      _pos_credit_notes.credit_note_year AS sales_year,
      _pos_credit_notes.credit_note_month AS sales_month,
      _pos_credit_notes.credit_note_day AS sales_day
    FROM _pos_credit_notes
    WHERE
      _pos_credit_notes.person_id_seller IS NOT NULL
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
  REPLACE INTO erp_biz_consolidated_sales_pos_item (
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
      erp_pos_invoice_detail.company_key,
      _pos_invoices.branch_id,
      erp_pos_invoice_detail.item_id,
      erp_pos_invoice_detail.invoice_detail_quantity * erp_pos_invoice_detail.invoice_detail_unit_value AS sales_total,
      0.00000000 AS sales_total_refund,
      _pos_invoices.invoice_date AS sales_date,
      _pos_invoices.invoice_year AS sales_year,
      _pos_invoices.invoice_month AS sales_month,
      _pos_invoices.invoice_day AS sales_day
    FROM erp_pos_invoice_detail
    INNER JOIN _pos_invoices ON _pos_invoices.id = erp_pos_invoice_detail.invoice_id
    WHERE
      (_company_key IS NULL OR erp_pos_invoice_detail.company_key = _company_key) AND
      (_date_from IS NULL OR _pos_invoices.invoice_year >= YEAR(_date_from)) AND
      (_date_from IS NULL OR _pos_invoices.invoice_month >= MONTH(_date_from)) AND
      NOT erp_pos_invoice_detail.invoice_detail_is_present
    ) UNION ALL (
    SELECT
      erp_pos_credit_note_details.company_key,
      _pos_credit_notes.branch_id,
      erp_pos_credit_note_details.item_id,
      0.00000000 AS sales_total,
      erp_pos_credit_note_details.credit_note_detail_quantity * erp_pos_credit_note_details.credit_note_detail_unit_value AS sales_total_refund,
      _pos_credit_notes.credit_note_date AS sales_date,
      _pos_credit_notes.credit_note_year AS sales_year,
      _pos_credit_notes.credit_note_month AS sales_month,
      _pos_credit_notes.credit_note_day AS sales_day
    FROM erp_pos_credit_note_details
    INNER JOIN _pos_credit_notes ON _pos_credit_notes.id = erp_pos_credit_note_details.credit_note_id
    WHERE
      (_company_key IS NULL OR erp_pos_credit_note_details.company_key = _company_key) AND
      (_date_from IS NULL OR _pos_credit_notes.credit_note_year >= YEAR(_date_from)) AND
      (_date_from IS NULL OR _pos_credit_notes.credit_note_month >= MONTH(_date_from)) AND
      NOT erp_pos_credit_note_details.credit_note_detail_is_present
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

  SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END //

CALL rebuild_erp_biz_consolidated_sales_pos(1394, NULL) //
