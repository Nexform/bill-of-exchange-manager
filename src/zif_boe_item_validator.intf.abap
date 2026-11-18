"! <p class="shorttext synchronized" lang="EN">Checks the cheques of a migration file</p>
"! The checks that look beyond the cells of one row: values that depend on
"! each other, the same cheque twice in the file, and master data that has to
"! exist. A check is skipped when a value it needs is initial -
"! {@link zif_boe_item_mapper} has reported that value already.
INTERFACE zif_boe_item_validator
  PUBLIC.

  "! Checks the cheques of one file.
  "!
  "! @parameter company_code | Company code of the migration run
  "! @parameter items        | The cheques of the file
  "! @parameter result       | The findings; each names the row it is about
  METHODS validate
    IMPORTING company_code  TYPE zboe_company_code
              items         TYPE zif_boe_migration=>items
    RETURNING VALUE(result) TYPE zif_boe_migration=>messages.

ENDINTERFACE.
