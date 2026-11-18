*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">A reader that returns the rows it was given</p>
CLASS ltd_reader DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_boe_xlsx_reader.

    "! Rows of the file; without any the file counts as unusable.
    DATA rows TYPE zif_boe_migration=>file_rows.
ENDCLASS.


CLASS ltd_reader IMPLEMENTATION.

  METHOD zif_boe_xlsx_reader~read.
    IF rows IS INITIAL.
      RAISE EXCEPTION NEW zcx_boe_file( ).
    ENDIF.

    result = rows.
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">A mapper that reports the rows it was told to</p>
CLASS ltd_mapper DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_boe_item_mapper.

    "! Messages about cells, by row.
    DATA cell_messages TYPE zif_boe_migration=>messages.
ENDCLASS.


CLASS ltd_mapper IMPLEMENTATION.

  METHOD zif_boe_item_mapper~map.
    result-item-row_number = row-row_number.
    result-item-boe_number = row-cells-boe_number.

    LOOP AT cell_messages INTO DATA(message) WHERE row_number = row-row_number.
      INSERT message INTO TABLE result-messages.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">A validator that returns the findings it was given</p>
CLASS ltd_validator DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_boe_item_validator.

    DATA findings TYPE zif_boe_migration=>messages.
    "! What the validator was asked to check.
    DATA checked_company_code TYPE zboe_company_code.
    DATA checked_items TYPE zif_boe_migration=>items.
ENDCLASS.


CLASS ltd_validator IMPLEMENTATION.

  METHOD zif_boe_item_validator~validate.
    checked_company_code = company_code.
    checked_items        = items.

    result = findings.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_run_check DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS company_code TYPE zboe_company_code VALUE 'GR01'.

    DATA reader TYPE REF TO ltd_reader.
    DATA mapper TYPE REF TO ltd_mapper.
    DATA validator TYPE REF TO ltd_validator.
    DATA cut TYPE REF TO zif_boe_run_check.

    "! A file with a cheque in row 2 and one in row 3.
    METHODS setup.

    METHODS check_file
      RETURNING VALUE(result) TYPE zif_boe_migration=>check_result
      RAISING   zcx_boe_file.

    METHODS given_clean_file_then_ready    FOR TESTING RAISING cx_static_check.
    METHODS given_cell_error_then_errors   FOR TESTING RAISING cx_static_check.
    METHODS given_finding_then_on_its_row  FOR TESTING RAISING cx_static_check.
    METHODS given_warning_then_ready       FOR TESTING RAISING cx_static_check.
    METHODS given_unusable_file_then_error FOR TESTING RAISING cx_static_check.
    METHODS when_checked_then_all_cheques  FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_run_check IMPLEMENTATION.

  METHOD setup.
    reader    = NEW #( ).
    mapper    = NEW #( ).
    validator = NEW #( ).

    reader->rows = VALUE #( ( row_number = 2 cells = VALUE #( boe_number = `A` ) )
                            ( row_number = 3 cells = VALUE #( boe_number = `B` ) ) ).

    cut = NEW zcl_boe_run_check( reader    = reader
                                 mapper    = mapper
                                 validator = validator ).
  ENDMETHOD.

  METHOD check_file.
    result = cut->check( file_content = VALUE #( )
                         company_code = company_code ).
  ENDMETHOD.

  METHOD given_clean_file_then_ready.
    " ACT
    DATA(outcome) = check_file( ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = outcome-item_count
                                        exp = 2
                                        msg = `Every row of the file is a cheque of the outcome` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-error_count
                                        exp = 0
                                        msg = `A file without messages has no cheque with errors` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-items[ 2 ]-status
                                        exp = zif_boe_migration=>item_status-ready
                                        msg = `A cheque without a message is ready` ).
  ENDMETHOD.

  METHOD given_cell_error_then_errors.
    " ARRANGE
    mapper->cell_messages = VALUE #( ( row_number = 2 severity = zif_boe_migration=>severity-error ) ).

    " ACT
    DATA(outcome) = check_file( ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = outcome-items[ 1 ]-status
                                        exp = zif_boe_migration=>item_status-has_errors
                                        msg = `A cheque with a cell that cannot be converted has errors` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-error_count
                                        exp = 1
                                        msg = `Only the cheque with the message counts as having errors` ).
  ENDMETHOD.

  METHOD given_finding_then_on_its_row.
    " ARRANGE
    mapper->cell_messages = VALUE #( ( row_number = 3 severity = zif_boe_migration=>severity-warning ) ).
    validator->findings   = VALUE #( ( row_number = 3 severity = zif_boe_migration=>severity-error ) ).

    " ACT
    DATA(outcome) = check_file( ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = outcome-items[ 1 ]-messages
                                         msg = `A finding belongs to the cheque of its row only` ).
    cl_abap_unit_assert=>assert_equals( act = lines( outcome-items[ 2 ]-messages )
                                        exp = 2
                                        msg = `Messages about cells and findings of the check are kept together` ).
    cl_abap_unit_assert=>assert_equals( act = outcome-items[ 2 ]-status
                                        exp = zif_boe_migration=>item_status-has_errors
                                        msg = `A finding that is an error gives the cheque errors` ).
  ENDMETHOD.

  METHOD given_warning_then_ready.
    " ARRANGE
    validator->findings = VALUE #( ( row_number = 2 severity = zif_boe_migration=>severity-warning ) ).

    " ACT
    DATA(outcome) = check_file( ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = outcome-items[ 1 ]-status
                                        exp = zif_boe_migration=>item_status-ready
                                        msg = `A warning does not stop a cheque` ).
  ENDMETHOD.

  METHOD given_unusable_file_then_error.
    " ARRANGE
    CLEAR reader->rows.

    " ACT / ASSERT
    TRY.
        check_file( ).
        cl_abap_unit_assert=>fail( msg = `A file the reader rejects must raise zcx_boe_file` ).
      CATCH zcx_boe_file.
        cl_abap_unit_assert=>assert_initial( act = validator->checked_company_code
                                             msg = `Nothing is checked when the file as a whole is unusable` ).
    ENDTRY.
  ENDMETHOD.

  METHOD when_checked_then_all_cheques.
    " ACT
    check_file( ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( validator->checked_items )
                                        exp = 2
                                        msg = `The cheques are checked together, as one file` ).
    cl_abap_unit_assert=>assert_equals( act = validator->checked_company_code
                                        exp = company_code
                                        msg = `The cheques are checked for the company code of the run` ).
  ENDMETHOD.

ENDCLASS.
