USE erp_1029;

DELIMITER //

DROP PROCEDURE IF EXISTS __pos_sales_report_rebuild //
CREATE DEFINER=`rootsa`@`%` PROCEDURE `__pos_sales_report_rebuild`()
LANGUAGE SQL
NOT DETERMINISTIC
CONTAINS SQL
SQL SECURITY INVOKER
COMMENT ''
BEGIN
  DROP TEMPORARY TABLE IF EXISTS __pos_sales_report;
  CREATE TEMPORARY TABLE IF NOT EXISTS __pos_sales_report
  SELECT
    company_key,
    branch_id,
    person_id_seller,
    SUM(sales_total) AS sales_total,
    SUM(sales_total_refund) AS sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  FROM ((
    SELECT
      erp_pos_credit_notes.company_key,
      erp_pos_credit_notes.branch_id,
      erp_pos_credit_notes.person_id_seller,
      0.000000 AS sales_total,
      erp_pos_credit_notes.credit_note_subtotal AS sales_total_refund,
      erp_pos_credit_notes.credit_note_date AS sales_date,
      erp_pos_credit_notes.credit_note_year AS sales_year,
      erp_pos_credit_notes.credit_note_month AS sales_month,
      erp_pos_credit_notes.credit_note_day AS sales_day
    FROM erp_pos_credit_notes
    WHERE
      erp_pos_credit_notes.company_key = 1616 AND
      erp_pos_credit_notes.credit_note_year = 2022 AND
      erp_pos_credit_notes.credit_note_month = 1
    ) UNION ALL (
    SELECT
      erp_pos_invoice.company_key,
      erp_pos_invoice.branch_id,
      erp_pos_invoice.person_id_seller,
      erp_pos_invoice.invoice_subtotal AS sales_total,
      0.000000 AS sales_total_refund,
      erp_pos_invoice.invoice_date AS sales_date,
      erp_pos_invoice.invoice_year AS sales_year,
      erp_pos_invoice.invoice_month AS sales_month,
      erp_pos_invoice.invoice_day AS sales_day
    FROM erp_pos_invoice
    WHERE
      erp_pos_invoice.invoice_type = 'IN' AND
      erp_pos_invoice.invoice_status IN ('PD', 'CL') AND
      erp_pos_invoice.company_key = 1616 AND
      erp_pos_invoice.invoice_year = 2022 AND
      erp_pos_invoice.invoice_month = 1
  )) report
  GROUP BY
    company_key,
    branch_id,
    person_id_seller,
    sales_date
  ;

  /* Ventas por SUCURSAL */
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
    company_key,
    branch_id,
    SUM(sales_total) AS sales_total,
    SUM(sales_total_refund) AS sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  FROM __pos_sales_report
  GROUP BY
    company_key,
    branch_id,
    sales_date
  ;

  /* Ventas por VENDEDOR */
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
    company_key,
    person_id_seller,
    SUM(sales_total) AS sales_total,
    SUM(sales_total_refund) AS sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  FROM __pos_sales_report
  WHERE
    person_id_seller IS NOT NULL
  GROUP BY
    company_key,
    person_id_seller,
    sales_date
  ;

  /* Ventas por ITEM */
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
    company_key,
    branch_id,
    item_id,
    SUM(sales_total) AS sales_total,
    SUM(sales_total_refund) AS sales_total_refund,
    sales_date,
    sales_year,
    sales_month,
    sales_day
  FROM ((
    SELECT
      erp_pos_credit_note_details.company_key,
      erp_pos_credit_notes.branch_id,
      erp_pos_credit_note_details.item_id,
      0.000000 AS sales_total,
      IFNULL(erp_pos_credit_note_details.credit_note_detail_quantity * erp_pos_credit_note_details.credit_note_detail_unit_value, 0.000000) AS sales_total_refund,
      erp_pos_credit_notes.credit_note_date AS sales_date,
      erp_pos_credit_notes.credit_note_year AS sales_year,
      erp_pos_credit_notes.credit_note_month AS sales_month,
      erp_pos_credit_notes.credit_note_day AS sales_day
    FROM erp_pos_credit_note_details
    INNER JOIN erp_pos_credit_notes ON erp_pos_credit_notes.id = erp_pos_credit_note_details.credit_note_id
    WHERE
      erp_pos_credit_note_details.company_key = 1616 AND
      erp_pos_credit_notes.credit_note_year = 2022 AND
      erp_pos_credit_notes.credit_note_month = 1
  ) UNION ALL (
    SELECT
      erp_pos_invoice_detail.company_key,
      erp_pos_invoice.branch_id,
      erp_pos_invoice_detail.item_id,
      IFNULL(erp_pos_invoice_detail.invoice_detail_quantity * erp_pos_invoice_detail.invoice_detail_unit_value, 0.000000) AS sales_total,
      0.000000 AS sales_total_refund,
      erp_pos_invoice.invoice_date AS sales_date,
      erp_pos_invoice.invoice_year AS sales_year,
      erp_pos_invoice.invoice_month AS sales_month,
      erp_pos_invoice.invoice_day AS sales_day
    FROM erp_pos_invoice_detail
    INNER JOIN erp_pos_invoice ON erp_pos_invoice.id = erp_pos_invoice_detail.invoice_id
    WHERE
      erp_pos_invoice.invoice_type = 'IN' AND
      erp_pos_invoice.invoice_status IN ('PD', 'CL') AND
      erp_pos_invoice_detail.company_key = 1616 AND
      erp_pos_invoice.invoice_year = 2022 AND
      erp_pos_invoice.invoice_month = 1
  )) report_by_items
  GROUP BY
    company_key,
    branch_id,
    item_id,
    sales_date
  ;

  DROP TEMPORARY TABLE IF EXISTS __pos_sales_report;
END //

CALL __pos_sales_report_rebuild();
DROP PROCEDURE IF EXISTS __pos_sales_report_rebuild;