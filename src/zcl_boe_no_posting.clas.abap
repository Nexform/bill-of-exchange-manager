"! <p class="shorttext synchronized" lang="EN">Posting adapter of a system without an edition adapter</p>
"! What {@link zif_boe_posting_provider} hands out while no edition adapter is
"! registered. It posts nothing and reports that as a finding, so that the
"! application works as a pure register: bills that need no accounting
"! document can be created, every other bill is stopped by the check.
CLASS zcl_boe_no_posting DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_posting.

  PRIVATE SECTION.
    METHODS no_adapter_finding
      RETURNING VALUE(result) TYPE zif_boe_posting=>message.

    METHODS raise_no_adapter
      RAISING zcx_boe_posting.

ENDCLASS.



CLASS zcl_boe_no_posting IMPLEMENTATION.

  METHOD zif_boe_posting~check.
    result = VALUE #( ( no_adapter_finding( ) ) ).
  ENDMETHOD.

  METHOD zif_boe_posting~post.
    raise_no_adapter( ).
  ENDMETHOD.

  METHOD zif_boe_posting~reverse.
    raise_no_adapter( ).
  ENDMETHOD.

  METHOD zif_boe_posting~find_document.
    " nothing is ever posted without an edition adapter, so there is no document to find
    CLEAR result.
  ENDMETHOD.

  METHOD no_adapter_finding.
    MESSAGE e020(zboe) INTO DATA(text) ##NEEDED.
    result = VALUE #( id       = sy-msgid
                      number   = sy-msgno
                      severity = sy-msgty ).
  ENDMETHOD.

  METHOD raise_no_adapter.
    DATA(finding) = no_adapter_finding( ).

    RAISE EXCEPTION TYPE zcx_boe_posting
      MESSAGE ID finding-id TYPE finding-severity NUMBER finding-number
      EXPORTING
        messages = VALUE #( ( finding ) ).
  ENDMETHOD.

ENDCLASS.
