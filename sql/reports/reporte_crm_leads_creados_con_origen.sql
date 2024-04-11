SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT
  CONCAT_WS(' ', common_person.identification_type_name, CONCAT_WS('-', common_person.person_identification, common_person.person_identification_check)) AS Identificación,
  common_person.person_name AS `Razón social (nombre)`,
  crm_origins.origin_name AS Origen,
  IF(common_person.person_kind = 'Company', 'Empresa', 'Contacto') AS Tipo,
  common_person_status.person_status_name AS Etapa,
  common_person_state.person_state_name AS Estado
FROM common_person
INNER JOIN common_person_status ON common_person_status.id = common_person.person_status_id
INNER JOIN common_person_state ON common_person_state.id = common_person.person_state_id
INNER JOIN crm_origins ON crm_origins.id = common_person.origin_id
WHERE
  common_person.company_key = 1040 AND
  common_person.person_state_id IS NOT NULL AND
  common_person.person_created_at BETWEEN '2023-12-01' AND '2023-12-31 23:59:59'
ORDER BY
  common_person_status.person_status_order ASC,
  common_person_state.person_state_order ASC
;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;