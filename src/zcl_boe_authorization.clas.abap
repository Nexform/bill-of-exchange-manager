"! <p class="shorttext synchronized" lang="EN">Authorization check against F_BKPF_BUK</p>
"! Production implementation of {@link zif_boe_authorization}: a thin wrapper
"! around AUTHORITY-CHECK on F_BKPF_BUK, the company code authorization of
"! accounting documents. It holds no logic of its own; what the application
"! does with the answer is tested with a double of the interface.
CLASS zcl_boe_authorization DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_authorization.

  PRIVATE SECTION.
    "! Activity 01: create or generate - posting a document.
    CONSTANTS post_activity TYPE c LENGTH 2 VALUE '01'.

ENDCLASS.



CLASS zcl_boe_authorization IMPLEMENTATION.

  METHOD zif_boe_authorization~is_create_allowed.
    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
      ID 'BUKRS' DUMMY
      ID 'ACTVT' FIELD post_activity.

    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD zif_boe_authorization~is_change_allowed.
    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
      ID 'BUKRS' FIELD company_code
      ID 'ACTVT' FIELD post_activity.

    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.
