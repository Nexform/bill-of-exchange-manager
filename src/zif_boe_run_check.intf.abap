"! <p class="shorttext synchronized" lang="EN">Check of the file of a migration run</p>
"! Takes the uploaded file from workbook to checked cheques: reads the rows,
"! converts them and checks them. Reads only - what becomes of the outcome is
"! the business of the caller.
INTERFACE zif_boe_run_check
  PUBLIC.

  "! Checks the file of a migration run.
  "!
  "! @parameter file_content | The workbook as it was uploaded
  "! @parameter company_code | Company code of the migration run
  "! @parameter result       | Every cheque of the file with its status and its messages
  "! @raising   zcx_boe_file | The file as a whole is unusable; no cheque was checked
  METHODS check
    IMPORTING file_content  TYPE xstring
              company_code  TYPE zboe_company_code
    RETURNING VALUE(result) TYPE zif_boe_migration=>check_result
    RAISING   zcx_boe_file.

ENDINTERFACE.
