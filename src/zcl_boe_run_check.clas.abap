"! <p class="shorttext synchronized" lang="EN">Check of the file of a migration run</p>
"! Strings reader, mapper and validator together and decides the status of
"! every cheque: a cheque with an error message has errors, every other is ready.
CLASS zcl_boe_run_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_run_check.

    "! @parameter reader    | Reads the rows of the workbook
    "! @parameter mapper    | Converts a row into a cheque
    "! @parameter validator | Checks the cheques of the file
    METHODS constructor
      IMPORTING reader    TYPE REF TO zif_boe_xlsx_reader
                mapper    TYPE REF TO zif_boe_item_mapper
                validator TYPE REF TO zif_boe_item_validator.

  PRIVATE SECTION.
    "! The findings of the validator, to be handed out row by row.
    TYPES findings_by_row TYPE SORTED TABLE OF zif_boe_migration=>message WITH NON-UNIQUE KEY row_number.

    DATA reader TYPE REF TO zif_boe_xlsx_reader.
    DATA mapper TYPE REF TO zif_boe_item_mapper.
    DATA validator TYPE REF TO zif_boe_item_validator.

    METHODS converted
      IMPORTING rows          TYPE zif_boe_migration=>file_rows
      RETURNING VALUE(result) TYPE zif_boe_migration=>checked_items.

    METHODS status_of
      IMPORTING messages      TYPE zif_boe_migration=>messages
      RETURNING VALUE(result) TYPE zboe_item_status.

ENDCLASS.



CLASS zcl_boe_run_check IMPLEMENTATION.

  METHOD constructor.
    me->reader    = reader.
    me->mapper    = mapper.
    me->validator = validator.
  ENDMETHOD.

  METHOD zif_boe_run_check~check.
    result-items = converted( reader->read( file_content ) ).

    DATA(findings) = CONV findings_by_row(
                       validator->validate( company_code = company_code
                                            items        = VALUE #( FOR checked IN result-items
                                                                    ( checked-item ) ) ) ).

    LOOP AT result-items ASSIGNING FIELD-SYMBOL(<checked>).
      LOOP AT findings INTO DATA(finding) WHERE row_number = <checked>-item-row_number.
        INSERT finding INTO TABLE <checked>-messages.
      ENDLOOP.

      <checked>-status = status_of( <checked>-messages ).
      IF <checked>-status = zif_boe_migration=>item_status-has_errors.
        result-error_count = result-error_count + 1.
      ENDIF.
    ENDLOOP.

    result-item_count = lines( result-items ).
  ENDMETHOD.

  METHOD converted.
    LOOP AT rows INTO DATA(row).
      DATA(mapped) = mapper->map( row ).
      INSERT VALUE #( item     = mapped-item
                      messages = mapped-messages )
             INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD status_of.
    result = COND #( WHEN line_exists( messages[ severity = zif_boe_migration=>severity-error ] )
                     THEN zif_boe_migration=>item_status-has_errors
                     ELSE zif_boe_migration=>item_status-ready ).
  ENDMETHOD.

ENDCLASS.
