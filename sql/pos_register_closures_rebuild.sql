USE erp_1000;

DELIMITER //

DROP TEMPORARY TABLE IF EXISTS `_pos_register_closures`;
CREATE TEMPORARY TABLE IF NOT EXISTS `_pos_register_closures`
WITH
  _pos_register_closures AS (
    SELECT erp_pos_register_closures.*
    FROM erp_pos_register_closures
    WHERE erp_pos_register_closures.register_closure_created_at >= '2022-06-01'
    ORDER BY erp_pos_register_closures.register_closure_created_at DESC
  ),
  _pos_expenses AS (
    SELECT
      _pos_register_closures.id AS register_closure_id,
      erp_pos_expenses.*
    FROM _pos_register_closures
    INNER JOIN erp_pos_expenses ON
      erp_pos_expenses.company_key = _pos_register_closures.company_key AND
      erp_pos_expenses.branch_id = _pos_register_closures.branch_id AND
      erp_pos_expenses.register_id = _pos_register_closures.register_id
    WHERE erp_pos_expenses.expense_date_time BETWEEN _pos_register_closures.register_opened_at AND _pos_register_closures.register_closure_created_at
    ORDER BY erp_pos_expenses.expense_created_at DESC
  ),
  _pos_invoices AS (
    SELECT
      _pos_register_closures.id AS register_closure_id,
      erp_pos_invoice.*
    FROM _pos_register_closures
    INNER JOIN erp_pos_invoice ON
      erp_pos_invoice.company_key = _pos_register_closures.company_key AND
      erp_pos_invoice.branch_id = _pos_register_closures.branch_id AND
      erp_pos_invoice.register_id = _pos_register_closures.register_id
    WHERE erp_pos_invoice.invoice_created_at BETWEEN _pos_register_closures.register_opened_at AND _pos_register_closures.register_closure_created_at
    ORDER BY erp_pos_invoice.invoice_consecutive ASC
  ),

  /* #region Facturas de venta */
  _pos_invoices_IN AS (SELECT _pos_invoices.* FROM _pos_invoices WHERE _pos_invoices.invoice_type = 'IN'),
  _pos_invoices_IN_payment_types AS (
    SELECT
      _pos_invoices_IN.register_closure_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeCode') THEN _payment_types.payment_type_object -> '$.PaymentTypeCode'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeCode') THEN _payment_types.payment_type_object -> '$.paymentTypeCode'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_code') THEN _payment_types.payment_type_object -> '$.payment_type_code'
        ELSE NULL
      END AS payment_type_code,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeName') THEN _payment_types.payment_type_object -> '$.PaymentTypeName'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeName') THEN _payment_types.payment_type_object -> '$.paymentTypeName'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_name') THEN _payment_types.payment_type_object -> '$.payment_type_name'
        ELSE NULL
      END AS payment_type_name,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeIsCash') THEN CAST(_payment_types.payment_type_object -> '$.PaymentTypeIsCash' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeIsCash') THEN CAST(_payment_types.payment_type_object -> '$.paymentTypeIsCash' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_is_cash') THEN CAST(_payment_types.payment_type_object -> '$.payment_type_is_cash' AS CHAR) = 'true'
        ELSE FALSE
      END AS payment_type_is_cash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.AccountCode_Bankcash') THEN _payment_types.payment_type_object -> '$.AccountCode_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.accountCode_Bankcash') THEN _payment_types.payment_type_object -> '$.accountCode_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.account_code_bankcash') THEN _payment_types.payment_type_object -> '$.account_code_bankcash'
        ELSE NULL
      END AS account_code_bankcash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.AccountName_Bankcash') THEN _payment_types.payment_type_object -> '$.AccountName_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.accountName_Bankcash') THEN _payment_types.payment_type_object -> '$.accountName_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.account_name_bankcash') THEN _payment_types.payment_type_object -> '$.account_name_bankcash'
        ELSE NULL
      END AS account_name_bankcash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.InvoicePaymentValue') THEN _payment_types.payment_type_object -> '$.InvoicePaymentValue'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoicePaymentValue') THEN _payment_types.payment_type_object -> '$.invoicePaymentValue'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoice_payment_value') THEN _payment_types.payment_type_object -> '$.invoice_payment_value'
        ELSE 0.000000
      END AS invoice_payment_value,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.InvoicePaymentReference') THEN _payment_types.payment_type_object -> '$.InvoicePaymentReference'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoicePaymentReference') THEN _payment_types.payment_type_object -> '$.invoicePaymentReference'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoice_payment_reference') THEN _payment_types.payment_type_object -> '$.invoice_payment_reference'
        ELSE NULL
      END AS invoice_payment_reference
    FROM _pos_invoices_IN
    INNER JOIN JSON_TABLE(CAST(_pos_invoices_IN.invoice_payment_types AS JSON), '$[*]' COLUMNS(payment_type_object JSON PATH '$')) _payment_types
  ),
  _pos_invoices_IN_payment_types_cash_total AS (
    SELECT
      _pos_invoices_IN_payment_types.register_closure_id,
      SUM(_pos_invoices_IN_payment_types.invoice_payment_value) AS invoice_payment_value
    FROM _pos_invoices_IN_payment_types
    WHERE
      _pos_invoices_IN_payment_types.payment_type_is_cash
    GROUP BY
      _pos_invoices_IN_payment_types.register_closure_id,
      _pos_invoices_IN_payment_types.payment_type_code
  ),
  _pos_invoices_IN_payment_types_total AS (
    SELECT
      _pos_invoices_IN_payment_types.register_closure_id,
      _pos_invoices_IN_payment_types.payment_type_code,
      _pos_invoices_IN_payment_types.payment_type_name,
      _pos_invoices_IN_payment_types.payment_type_is_cash,
      _pos_invoices_IN_payment_types.account_code_bankcash,
      _pos_invoices_IN_payment_types.account_name_bankcash,
      SUM(_pos_invoices_IN_payment_types.invoice_payment_value) AS invoice_payment_value,
      JSON_ARRAYAGG(_pos_invoices_IN_payment_types.invoice_payment_reference) AS invoice_payment_reference
    FROM _pos_invoices_IN_payment_types
    GROUP BY
      _pos_invoices_IN_payment_types.register_closure_id,
      _pos_invoices_IN_payment_types.payment_type_code
  ),
  _pos_invoices_IN_payment_types_json AS (
    SELECT
      _pos_invoices_IN_payment_types_total.register_closure_id,
      JSON_ARRAYAGG(JSON_OBJECT(
        'paymentTypeCode', _pos_invoices_IN_payment_types_total.payment_type_code,
        'paymentTypeName', _pos_invoices_IN_payment_types_total.payment_type_name,
        'paymentTypeIsCash', _pos_invoices_IN_payment_types_total.payment_type_is_cash = 1,
        'accountCode_Bankcash', _pos_invoices_IN_payment_types_total.account_code_bankcash,
        'accountName_Bankcash', _pos_invoices_IN_payment_types_total.account_name_bankcash,
        'invoicePaymentValue', _pos_invoices_IN_payment_types_total.invoice_payment_value,
        'invoicePaymentReference', CAST((
          SELECT GROUP_CONCAT(_payment_references._payment_reference SEPARATOR ',')
          FROM JSON_TABLE(_pos_invoices_IN_payment_types_total.invoice_payment_reference, '$[*]' COLUMNS(_payment_reference VARCHAR(128) PATH '$')) _payment_references
          WHERE _payment_references._payment_reference != null
        ) AS JSON)
      )) AS _payment_types_json
    FROM _pos_invoices_IN_payment_types_total
    GROUP BY _pos_invoices_IN_payment_types_total.register_closure_id
  ),
  _pos_invoices_IN_taxes AS (
    SELECT
      _pos_invoices_IN.register_closure_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxId') THEN _taxes.tax_object -> '$.TaxId'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxId') THEN _taxes.tax_object -> '$.taxId'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_id') THEN _taxes.tax_object -> '$.tax_id'
        ELSE NULL
        END AS tax_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxNametaxName') THEN _taxes.tax_object -> '$.TaxNametaxName'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxNametaxName') THEN _taxes.tax_object -> '$.taxNametaxName'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_nametax_name') THEN _taxes.tax_object -> '$.tax_nametax_name'
        ELSE NULL
        END AS tax_name,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxCategory') THEN _taxes.tax_object -> '$.TaxCategory'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxCategory') THEN _taxes.tax_object -> '$.taxCategory'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_category') THEN _taxes.tax_object -> '$.tax_category'
        ELSE NULL
        END AS tax_category,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxIsSum') THEN CAST(_taxes.tax_object -> '$.TaxIsSum' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxIsSum') THEN CAST(_taxes.tax_object -> '$.taxIsSum' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_is_sum') THEN CAST(_taxes.tax_object -> '$.tax_is_sum' AS CHAR) = 'true'
        ELSE FALSE
        END AS tax_is_sum,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxPercentValue') THEN _taxes.tax_object -> '$.TaxPercentValue'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxPercentValue') THEN _taxes.tax_object -> '$.taxPercentValue'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_percent_value') THEN _taxes.tax_object -> '$.tax_percent_value'
        ELSE 0.000000
        END AS tax_percent_value,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxBase') THEN _taxes.tax_object -> '$.TaxBase'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxBase') THEN _taxes.tax_object -> '$.taxBase'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_base') THEN _taxes.tax_object -> '$.tax_base'
        ELSE 0.000000
        END AS tax_base,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxIsDiscriminate') THEN CAST(_taxes.tax_object -> '$.TaxIsDiscriminate' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxIsDiscriminate') THEN CAST(_taxes.tax_object -> '$.taxIsDiscriminate' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_is_discriminate') THEN CAST(_taxes.tax_object -> '$.tax_is_discriminate' AS CHAR) = 'true'
        ELSE FALSE
        END AS tax_is_discriminate,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxExemptionReason') THEN _taxes.tax_object -> '$.TaxExemptionReason'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxExemptionReason') THEN _taxes.tax_object -> '$.taxExemptionReason'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_exemption_reason') THEN _taxes.tax_object -> '$.tax_exemption_reason'
        ELSE NULL
        END AS tax_exemption_reason,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._SubTotal') THEN _taxes.tax_object -> '$._SubTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._subTotal') THEN _taxes.tax_object -> '$._subTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.SubTotal') THEN _taxes.tax_object -> '$.SubTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.subTotal') THEN _taxes.tax_object -> '$.subTotal'
        ELSE 0.000000
      END AS sub_total,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._ValueTotal') THEN _taxes.tax_object -> '$._ValueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._valueTotal') THEN _taxes.tax_object -> '$._valueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.ValueTotal') THEN _taxes.tax_object -> '$.ValueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.valueTotal') THEN _taxes.tax_object -> '$.valueTotal'
        ELSE 0.000000
      END AS value_total
    FROM _pos_invoices_IN
    INNER JOIN JSON_TABLE(CAST(_pos_invoices_IN.invoice_taxes AS JSON), '$[*]' COLUMNS(tax_object JSON PATH '$')) _taxes
  ),
  _pos_invoices_IN_taxes_total AS (
    SELECT
      _pos_invoices_IN_taxes.register_closure_id,
      _pos_invoices_IN_taxes.tax_id,
      _pos_invoices_IN_taxes.tax_name,
      _pos_invoices_IN_taxes.tax_category,
      _pos_invoices_IN_taxes.tax_is_sum,
      _pos_invoices_IN_taxes.tax_percent_value,
      _pos_invoices_IN_taxes.tax_base,
      _pos_invoices_IN_taxes.tax_is_discriminate,
      _pos_invoices_IN_taxes.tax_exemption_reason,
      SUM(_pos_invoices_IN_taxes.sub_total) AS sub_total,
      SUM(_pos_invoices_IN_taxes.value_total) AS value_total
    FROM _pos_invoices_IN_taxes
    GROUP BY
      _pos_invoices_IN_taxes.register_closure_id,
      _pos_invoices_IN_taxes.tax_id
  ),
  _pos_invoices_IN_taxes_json AS (
    SELECT
      _pos_invoices_IN_taxes_total.register_closure_id,
      JSON_ARRAYAGG(JSON_OBJECT(
        'taxId', _pos_invoices_IN_taxes_total.tax_id,
        'taxName', _pos_invoices_IN_taxes_total.tax_name,
        'taxCategory', _pos_invoices_IN_taxes_total.tax_category,
        'taxIsSum', _pos_invoices_IN_taxes_total.tax_is_sum = 1,
        'taxPercentValue', _pos_invoices_IN_taxes_total.tax_percent_value,
        'taxBase', _pos_invoices_IN_taxes_total.tax_base,
        'taxIsDiscriminate', _pos_invoices_IN_taxes_total.tax_is_discriminate = 1,
        'taxExemptionReason', _pos_invoices_IN_taxes_total.tax_exemption_reason,
        '_SubTotal', _pos_invoices_IN_taxes_total.sub_total,
        '_ValueTotal', _pos_invoices_IN_taxes_total.value_total
      )) AS _taxes_json
    FROM _pos_invoices_IN_taxes_total
    GROUP BY _pos_invoices_IN_taxes_total.register_closure_id
  ),
  /* #endregion Facturas de venta */

  /* #region Notas crédito */
  _pos_invoices_RF AS (SELECT _pos_invoices.* FROM _pos_invoices WHERE _pos_invoices.invoice_type = 'RF'),
  _pos_invoices_RF_payment_types AS (
    SELECT
      _pos_invoices_RF.register_closure_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeCode') THEN _payment_types.payment_type_object -> '$.PaymentTypeCode'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeCode') THEN _payment_types.payment_type_object -> '$.paymentTypeCode'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_code') THEN _payment_types.payment_type_object -> '$.payment_type_code'
        ELSE NULL
      END AS payment_type_code,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeName') THEN _payment_types.payment_type_object -> '$.PaymentTypeName'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeName') THEN _payment_types.payment_type_object -> '$.paymentTypeName'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_name') THEN _payment_types.payment_type_object -> '$.payment_type_name'
        ELSE NULL
      END AS payment_type_name,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.PaymentTypeIsCash') THEN CAST(_payment_types.payment_type_object -> '$.PaymentTypeIsCash' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.paymentTypeIsCash') THEN CAST(_payment_types.payment_type_object -> '$.paymentTypeIsCash' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.payment_type_is_cash') THEN CAST(_payment_types.payment_type_object -> '$.payment_type_is_cash' AS CHAR) = 'true'
        ELSE FALSE
      END AS payment_type_is_cash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.AccountCode_Bankcash') THEN _payment_types.payment_type_object -> '$.AccountCode_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.accountCode_Bankcash') THEN _payment_types.payment_type_object -> '$.accountCode_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.account_code_bankcash') THEN _payment_types.payment_type_object -> '$.account_code_bankcash'
        ELSE NULL
      END AS account_code_bankcash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.AccountName_Bankcash') THEN _payment_types.payment_type_object -> '$.AccountName_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.accountName_Bankcash') THEN _payment_types.payment_type_object -> '$.accountName_Bankcash'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.account_name_bankcash') THEN _payment_types.payment_type_object -> '$.account_name_bankcash'
        ELSE NULL
      END AS account_name_bankcash,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.InvoicePaymentValue') THEN _payment_types.payment_type_object -> '$.InvoicePaymentValue'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoicePaymentValue') THEN _payment_types.payment_type_object -> '$.invoicePaymentValue'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoice_payment_value') THEN _payment_types.payment_type_object -> '$.invoice_payment_value'
        ELSE 0.000000
      END AS invoice_payment_value,
      CASE
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.InvoicePaymentReference') THEN _payment_types.payment_type_object -> '$.InvoicePaymentReference'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoicePaymentReference') THEN _payment_types.payment_type_object -> '$.invoicePaymentReference'
        WHEN JSON_CONTAINS_PATH(_payment_types.payment_type_object, 'one', '$.invoice_payment_reference') THEN _payment_types.payment_type_object -> '$.invoice_payment_reference'
        ELSE NULL
      END AS invoice_payment_reference
    FROM _pos_invoices_RF
    INNER JOIN JSON_TABLE(CAST(_pos_invoices_RF.invoice_payment_types AS JSON), '$[*]' COLUMNS(payment_type_object JSON PATH '$')) _payment_types
  ),
  _pos_invoices_RF_payment_types_cash_total AS (
    SELECT
      _pos_invoices_RF_payment_types.register_closure_id,
      SUM(_pos_invoices_RF_payment_types.invoice_payment_value) AS invoice_payment_value
    FROM _pos_invoices_RF_payment_types
    WHERE
      _pos_invoices_RF_payment_types.payment_type_is_cash
    GROUP BY
      _pos_invoices_RF_payment_types.register_closure_id,
      _pos_invoices_RF_payment_types.payment_type_code
  ),
  _pos_invoices_RF_payment_types_total AS (
    SELECT
      _pos_invoices_RF_payment_types.register_closure_id,
      _pos_invoices_RF_payment_types.payment_type_code,
      _pos_invoices_RF_payment_types.payment_type_name,
      _pos_invoices_RF_payment_types.payment_type_is_cash,
      _pos_invoices_RF_payment_types.account_code_bankcash,
      _pos_invoices_RF_payment_types.account_name_bankcash,
      SUM(_pos_invoices_RF_payment_types.invoice_payment_value) AS invoice_payment_value,
      JSON_ARRAYAGG(_pos_invoices_RF_payment_types.invoice_payment_reference) AS invoice_payment_reference
    FROM _pos_invoices_RF_payment_types
    GROUP BY
      _pos_invoices_RF_payment_types.register_closure_id,
      _pos_invoices_RF_payment_types.payment_type_code
  ),
  _pos_invoices_RF_payment_types_json AS (
    SELECT
      _pos_invoices_RF_payment_types_total.register_closure_id,
      JSON_ARRAYAGG(JSON_OBJECT(
        'paymentTypeCode', _pos_invoices_RF_payment_types_total.payment_type_code,
        'paymentTypeName', _pos_invoices_RF_payment_types_total.payment_type_name,
        'paymentTypeIsCash', _pos_invoices_RF_payment_types_total.payment_type_is_cash = 1,
        'accountCode_Bankcash', _pos_invoices_RF_payment_types_total.account_code_bankcash,
        'accountName_Bankcash', _pos_invoices_RF_payment_types_total.account_name_bankcash,
        'invoicePaymentValue', _pos_invoices_RF_payment_types_total.invoice_payment_value,
        'invoicePaymentReference', CAST((
          SELECT GROUP_CONCAT(_payment_references._payment_reference SEPARATOR ',')
          FROM JSON_TABLE(_pos_invoices_RF_payment_types_total.invoice_payment_reference, '$[*]' COLUMNS(_payment_reference VARCHAR(128) PATH '$')) _payment_references
          WHERE _payment_references._payment_reference != null
        ) AS JSON)
      )) AS _payment_types_json
    FROM _pos_invoices_RF_payment_types_total
    GROUP BY _pos_invoices_RF_payment_types_total.register_closure_id
  ),
  _pos_invoices_RF_taxes AS (
    SELECT
      _pos_invoices_RF.register_closure_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxId') THEN _taxes.tax_object -> '$.TaxId'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxId') THEN _taxes.tax_object -> '$.taxId'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_id') THEN _taxes.tax_object -> '$.tax_id'
        ELSE NULL
      END AS tax_id,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxNametaxName') THEN _taxes.tax_object -> '$.TaxNametaxName'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxNametaxName') THEN _taxes.tax_object -> '$.taxNametaxName'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_nametax_name') THEN _taxes.tax_object -> '$.tax_nametax_name'
        ELSE NULL
      END AS tax_name,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxCategory') THEN _taxes.tax_object -> '$.TaxCategory'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxCategory') THEN _taxes.tax_object -> '$.taxCategory'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_category') THEN _taxes.tax_object -> '$.tax_category'
        ELSE NULL
        END AS tax_category,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxIsSum') THEN CAST(_taxes.tax_object -> '$.TaxIsSum' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxIsSum') THEN CAST(_taxes.tax_object -> '$.taxIsSum' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_is_sum') THEN CAST(_taxes.tax_object -> '$.tax_is_sum' AS CHAR) = 'true'
        ELSE FALSE
      END AS tax_is_sum,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxPercentValue') THEN _taxes.tax_object -> '$.TaxPercentValue'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxPercentValue') THEN _taxes.tax_object -> '$.taxPercentValue'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_percent_value') THEN _taxes.tax_object -> '$.tax_percent_value'
        ELSE 0.000000
      END AS tax_percent_value,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxBase') THEN _taxes.tax_object -> '$.TaxBase'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxBase') THEN _taxes.tax_object -> '$.taxBase'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_base') THEN _taxes.tax_object -> '$.tax_base'
        ELSE 0.000000
      END AS tax_base,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxIsDiscriminate') THEN CAST(_taxes.tax_object -> '$.TaxIsDiscriminate' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxIsDiscriminate') THEN CAST(_taxes.tax_object -> '$.taxIsDiscriminate' AS CHAR) = 'true'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_is_discriminate') THEN CAST(_taxes.tax_object -> '$.tax_is_discriminate' AS CHAR) = 'true'
        ELSE FALSE
      END AS tax_is_discriminate,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.TaxExemptionReason') THEN _taxes.tax_object -> '$.TaxExemptionReason'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.taxExemptionReason') THEN _taxes.tax_object -> '$.taxExemptionReason'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.tax_exemption_reason') THEN _taxes.tax_object -> '$.tax_exemption_reason'
        ELSE NULL
      END AS tax_exemption_reason,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._SubTotal') THEN _taxes.tax_object -> '$._SubTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._subTotal') THEN _taxes.tax_object -> '$._subTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.SubTotal') THEN _taxes.tax_object -> '$.SubTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.subTotal') THEN _taxes.tax_object -> '$.subTotal'
        ELSE 0.000000
      END AS sub_total,
      CASE
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._ValueTotal') THEN _taxes.tax_object -> '$._ValueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$._valueTotal') THEN _taxes.tax_object -> '$._valueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.ValueTotal') THEN _taxes.tax_object -> '$.ValueTotal'
        WHEN JSON_CONTAINS_PATH(_taxes.tax_object, 'one', '$.valueTotal') THEN _taxes.tax_object -> '$.valueTotal'
        ELSE 0.000000
      END AS value_total
    FROM _pos_invoices_RF
    INNER JOIN JSON_TABLE(CAST(_pos_invoices_RF.invoice_taxes AS JSON), '$[*]' COLUMNS(tax_object JSON PATH '$')) _taxes
  ),
  _pos_invoices_RF_taxes_total AS (
    SELECT
      _pos_invoices_RF_taxes.register_closure_id,
      _pos_invoices_RF_taxes.tax_id,
      _pos_invoices_RF_taxes.tax_name,
      _pos_invoices_RF_taxes.tax_category,
      _pos_invoices_RF_taxes.tax_is_sum,
      _pos_invoices_RF_taxes.tax_percent_value,
      _pos_invoices_RF_taxes.tax_base,
      _pos_invoices_RF_taxes.tax_is_discriminate,
      _pos_invoices_RF_taxes.tax_exemption_reason,
      SUM(_pos_invoices_RF_taxes.sub_total) AS sub_total,
      SUM(_pos_invoices_RF_taxes.value_total) AS value_total
    FROM _pos_invoices_RF_taxes
    GROUP BY
      _pos_invoices_RF_taxes.register_closure_id,
      _pos_invoices_RF_taxes.tax_id
  ),
  _pos_invoices_RF_taxes_json AS (
    SELECT
      _pos_invoices_RF_taxes_total.register_closure_id,
      JSON_ARRAYAGG(JSON_OBJECT(
        'taxId', _pos_invoices_RF_taxes_total.tax_id,
        'taxName', _pos_invoices_RF_taxes_total.tax_name,
        'taxCategory', _pos_invoices_RF_taxes_total.tax_category,
        'taxIsSum', _pos_invoices_RF_taxes_total.tax_is_sum = 1,
        'taxPercentValue', _pos_invoices_RF_taxes_total.tax_percent_value,
        'taxBase', _pos_invoices_RF_taxes_total.tax_base,
        'taxIsDiscriminate', _pos_invoices_RF_taxes_total.tax_is_discriminate = 1,
        'taxExemptionReason', _pos_invoices_RF_taxes_total.tax_exemption_reason,
        '_SubTotal', _pos_invoices_RF_taxes_total.sub_total,
        '_ValueTotal', _pos_invoices_RF_taxes_total.value_total
      )) AS _taxes_json
    FROM _pos_invoices_RF_taxes_total
    GROUP BY _pos_invoices_RF_taxes_total.register_closure_id
  ),
  /* #endregion Notas crédito */

  /* #region Gastos */
  _pos_expense_totals AS (
    SELECT
      _pos_expenses.register_closure_id,
      SUM(_pos_expenses.expense_amount) AS expense_total
    FROM _pos_expenses
    GROUP BY _pos_expenses.register_closure_id
    )
  /* #endregion Gastos */
SELECT
  _pos_register_closures.id AS id,
  _pos_register_closures.company_key AS company_key,
  _pos_register_closures.register_id AS register_id,
  _pos_register_closures.branch_id AS branch_id,
  _pos_register_closures.document_id AS document_id,
  _pos_register_closures.document_id_refund AS document_id_refund,
  _pos_register_closures.register_closure_consecutive AS register_closure_consecutive,
  _pos_register_closures.register_closure_date AS register_closure_date,
  _pos_register_closures.register_closure_done AS register_closure_done,
  _pos_register_closures.register_closure_exception AS register_closure_exception,

  IFNULL(_pos_expense_totals.expense_total, 0.000000) AS register_closure_expense_total,
  _pos_register_closures.register_closure_opening_balance AS register_closure_opening_balance,
  IFNULL(_pos_invoices_IN_payment_types_cash_total.invoice_payment_value, 0.000000) AS register_closure_payment,
  -IFNULL(_pos_invoices_RF_payment_types_cash_total.invoice_payment_value, 0.000000) AS register_closure_refund,
  _pos_register_closures.register_closure_recount AS register_closure_recount,

  /* #region Facturas de venta */
  (SELECT IFNULL(MIN(_pos_invoices_IN.invoice_consecutive), 0) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_consecutive_from,
  (SELECT IFNULL(MAX(_pos_invoices_IN.invoice_consecutive), 0) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_consecutive_to,
  (SELECT IFNULL(COUNT(_pos_invoices_IN.id), 0) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_quantity,
  (SELECT IFNULL(SUM(_pos_invoices_IN.invoice_subtotal), 0.000000) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_subtotal,
  (SELECT IFNULL(SUM(_pos_invoices_IN.invoice_discount), 0.000000) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_discount,
  (SELECT IFNULL(SUM(_pos_invoices_IN_taxes.value_total), 0.000000) FROM _pos_invoices_IN_taxes WHERE _pos_invoices_IN_taxes.register_closure_id = _pos_register_closures.id AND _pos_invoices_IN_taxes.tax_is_sum) AS invoice_tax_sum,
  (SELECT IFNULL(SUM(_pos_invoices_IN_taxes.value_total), 0.000000) FROM _pos_invoices_IN_taxes WHERE _pos_invoices_IN_taxes.register_closure_id = _pos_register_closures.id AND NOT _pos_invoices_IN_taxes.tax_is_sum) AS invoice_tax_sub,
  (SELECT IFNULL(SUM(_pos_invoices_IN.invoice_total), 0.000000) FROM _pos_invoices_IN WHERE _pos_invoices_IN.register_closure_id = _pos_register_closures.id) AS invoice_total,
  _pos_invoices_IN_taxes_json._taxes_json AS invoice_taxes,
  _pos_invoices_IN_payment_types_json._payment_types_json AS invoice_payment_types,
  /* #endregion Facturas de venta */

  /* #region Notas crédito */
  (SELECT IFNULL(MIN(_pos_invoices_RF.invoice_consecutive), 0) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_consecutive_from_refund,
  (SELECT IFNULL(MAX(_pos_invoices_RF.invoice_consecutive), 0) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_consecutive_to_refund,
  (SELECT IFNULL(COUNT(_pos_invoices_RF.id), 0) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_quantity_refund,
  (SELECT IFNULL(SUM(_pos_invoices_RF.invoice_subtotal), 0.000000) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_subtotal_refund,
  (SELECT IFNULL(SUM(_pos_invoices_RF.invoice_discount), 0.000000) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_discount_refund,
  (SELECT IFNULL(SUM(_pos_invoices_RF_taxes.value_total), 0.000000) FROM _pos_invoices_RF_taxes WHERE _pos_invoices_RF_taxes.register_closure_id = _pos_register_closures.id AND _pos_invoices_RF_taxes.tax_is_sum) AS invoice_tax_sum_refund,
  (SELECT IFNULL(SUM(_pos_invoices_RF_taxes.value_total), 0.000000) FROM _pos_invoices_RF_taxes WHERE _pos_invoices_RF_taxes.register_closure_id = _pos_register_closures.id AND NOT _pos_invoices_RF_taxes.tax_is_sum) AS invoice_tax_sub_refund,
  (SELECT IFNULL(SUM(_pos_invoices_RF.invoice_total), 0.000000) FROM _pos_invoices_RF WHERE _pos_invoices_RF.register_closure_id = _pos_register_closures.id) AS invoice_total_refund,
  _pos_invoices_RF_taxes_json._taxes_json AS invoice_taxes_refund,
  _pos_invoices_RF_payment_types_json._payment_types_json AS invoice_payment_types_refund,
  /* #endregion Notas crédito */

  _pos_register_closures.register_opened_at,
  _pos_register_closures.register_closure_created_at,
  _pos_register_closures.register_closure_created_by,
  _pos_register_closures.register_closure_updated_at,
  _pos_register_closures.register_closure_updated_by
FROM _pos_register_closures
LEFT OUTER JOIN _pos_expense_totals ON _pos_expense_totals.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_IN_payment_types_json ON _pos_invoices_IN_payment_types_json.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_IN_payment_types_cash_total ON _pos_invoices_IN_payment_types_cash_total.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_IN_taxes_json ON _pos_invoices_IN_taxes_json.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_RF_payment_types_json ON _pos_invoices_RF_payment_types_json.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_RF_payment_types_cash_total ON _pos_invoices_RF_payment_types_cash_total.register_closure_id = _pos_register_closures.id
LEFT OUTER JOIN _pos_invoices_RF_taxes_json ON _pos_invoices_RF_taxes_json.register_closure_id = _pos_register_closures.id
;

SELECT * FROM _pos_register_closures
;