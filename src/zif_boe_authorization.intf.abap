"! <p class="shorttext synchronized" lang="EN">Authorization for bills of exchange</p>
"! Boundary between the application and the authorization concept of the
"! system. Whoever creates bills of exchange posts to financial accounting, so
"! the application asks for the authorization to post in a company code.
"! Production wires {@link zcl_boe_authorization}; tests inject a double.
INTERFACE zif_boe_authorization
  PUBLIC.

  "! Tells whether the user may post in at least one company code - the
  "! question before a migration run exists and names its company code.
  "!
  "! @parameter result | abap_true when the user may create migration runs
  METHODS is_create_allowed
    RETURNING VALUE(result) TYPE abap_bool.

  "! Tells whether the user may post in a company code.
  "!
  "! @parameter company_code | Company code of the migration run or of the bill
  "! @parameter result       | abap_true when the user may change what belongs to this company code
  METHODS is_change_allowed
    IMPORTING company_code  TYPE zboe_company_code
    RETURNING VALUE(result) TYPE abap_bool.

ENDINTERFACE.
