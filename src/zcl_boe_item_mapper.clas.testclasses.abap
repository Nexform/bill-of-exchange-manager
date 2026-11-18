*"* use this source file for your ABAP unit test classes

CLASS ltc_item_mapper DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    "! Message numbers of ZBOE that the conversion of a row reports.
    CONSTANTS:
      BEGIN OF finding,
        too_long        TYPE symsgno VALUE '050',
        no_date         TYPE symsgno VALUE '051',
        no_amount       TYPE symsgno VALUE '052',
        no_flag         TYPE symsgno VALUE '053',
        value_missing   TYPE symsgno VALUE '054',
        amount_not_plus TYPE symsgno VALUE '055',
      END OF finding.

    DATA cut TYPE REF TO zif_boe_item_mapper.

    METHODS setup.

    "! A row in which every cell can be converted.
    METHODS valid_row
      RETURNING VALUE(result) TYPE zif_boe_migration=>file_row.

    "! Asserts that the conversion reported a message about a column.
    METHODS assert_finding
      IMPORTING messages TYPE zif_boe_migration=>messages
                number   TYPE symsgno
                column   TYPE zboe_column_name.

    "! Converts a row that has the given due date and returns the date of the cheque.
    METHODS due_date_of
      IMPORTING cell          TYPE string
      RETURNING VALUE(result) TYPE zboe_due_date.

    METHODS given_valid_row_then_cheque    FOR TESTING.
    METHODS given_valid_row_then_no_msg    FOR TESTING.
    METHODS given_number_then_zeros_added  FOR TESTING.
    METHODS given_lower_case_then_upper    FOR TESTING.
    METHODS given_no_status_then_portfolio FOR TESTING.
    METHODS given_date_formats_then_date   FOR TESTING.
    METHODS given_excel_day_then_date      FOR TESTING.
    METHODS given_no_calendar_day_then_msg FOR TESTING.
    METHODS given_comma_then_amount        FOR TESTING.
    METHODS given_thousands_sep_then_msg   FOR TESTING.
    METHODS given_zero_amount_then_msg     FOR TESTING.
    METHODS given_empty_row_then_mandatory FOR TESTING.
    METHODS given_long_value_then_msg      FOR TESTING.
    METHODS given_x_then_register_only     FOR TESTING.
    METHODS given_other_flag_then_msg      FOR TESTING.

ENDCLASS.


CLASS ltc_item_mapper IMPLEMENTATION.

  METHOD setup.
    cut = NEW zcl_boe_item_mapper( ).
  ENDMETHOD.

  METHOD valid_row.
    result = VALUE #( row_number = 7
                      cells      = VALUE #( boe_number          = `00123456`
                                            customer            = `100001`
                                            amount              = `1500.50`
                                            currency            = `EUR`
                                            due_date            = `31.01.2027`
                                            issue_date          = `2026-11-30`
                                            target_status       = `30`
                                            drawer_name         = `Papadopoulos AE`
                                            drawee_bank_country = `GR`
                                            drawee_bank         = `0110`
                                            drawee_bank_name    = `National Bank of Greece`
                                            drawee_account      = `GR1601101250000000012300695`
                                            house_bank          = `NBG01`
                                            house_bank_account  = `EUR01`
                                            legacy_reference    = `LEG-4711`
                                            note                = `Handed over in October` ) ).
  ENDMETHOD.

  METHOD assert_finding.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( messages[ number = number
                                            column = column ] ) )
      msg = |Message { number } of ZBOE about column { column } was not reported| ).
  ENDMETHOD.

  METHOD due_date_of.
    DATA(row) = valid_row( ).
    row-cells-due_date = cell.

    result = cut->map( row )-item-due_date.
  ENDMETHOD.

  METHOD given_valid_row_then_cheque.
    " ACT
    DATA(cheque) = cut->map( valid_row( ) )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = cheque-row_number
                                        exp = 7
                                        msg = `The cheque keeps the row of the file it came from` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-boe_number
                                        exp = '00123456'
                                        msg = `A cheque number is text and keeps its leading zeros` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-amount
                                        exp = '1500.50'
                                        msg = `An amount with a decimal point must be converted` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-due_date
                                        exp = CONV zboe_due_date( '20270131' )
                                        msg = `A date DD.MM.YYYY must be converted` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-target_status
                                        exp = zif_boe_status_rules=>status-at_bank_for_collection
                                        msg = `The status of the file is the status the bill gets` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-note
                                        exp = 'Handed over in October'
                                        msg = `A text is taken over as it is` ).
  ENDMETHOD.

  METHOD given_valid_row_then_no_msg.
    " ACT
    DATA(messages) = cut->map( valid_row( ) )-messages.

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = messages
                                         msg = `A row in which every cell can be converted has no message` ).
  ENDMETHOD.

  METHOD given_number_then_zeros_added.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-customer = `4711`.

    " ACT
    DATA(cheque) = cut->map( row )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = cheque-customer
                                        exp = '0000004711'
                                        msg = `A customer number of digits is stored with leading zeros` ).
  ENDMETHOD.

  METHOD given_lower_case_then_upper.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-currency   = `eur`.
    row-cells-house_bank = `nbg01`.

    " ACT
    DATA(cheque) = cut->map( row )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = cheque-currency
                                        exp = 'EUR'
                                        msg = `Keys of master data are in upper case` ).
    cl_abap_unit_assert=>assert_equals( act = cheque-house_bank
                                        exp = 'NBG01'
                                        msg = `Keys of master data are in upper case` ).
  ENDMETHOD.

  METHOD given_no_status_then_portfolio.
    " ARRANGE
    DATA(row) = valid_row( ).
    CLEAR row-cells-target_status.

    " ACT
    DATA(cheque) = cut->map( row )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = cheque-target_status
                                        exp = zif_boe_status_rules=>status-in_portfolio
                                        msg = `A cheque without a status in the file is in the portfolio` ).
  ENDMETHOD.

  METHOD given_date_formats_then_date.
    " ACT / ASSERT
    DATA(expected) = CONV zboe_due_date( '20270205' ).

    cl_abap_unit_assert=>assert_equals( act = due_date_of( `20270205` )
                                        exp = expected
                                        msg = `YYYYMMDD is a date` ).
    cl_abap_unit_assert=>assert_equals( act = due_date_of( `05.02.2027` )
                                        exp = expected
                                        msg = `DD.MM.YYYY is a date` ).
    cl_abap_unit_assert=>assert_equals( act = due_date_of( `5/2/2027` )
                                        exp = expected
                                        msg = `D/M/YYYY is a date, day first` ).
    cl_abap_unit_assert=>assert_equals( act = due_date_of( `2027-02-05` )
                                        exp = expected
                                        msg = `YYYY-MM-DD is a date` ).
  ENDMETHOD.

  METHOD given_excel_day_then_date.
    " ACT
    DATA(due_date) = due_date_of( `46418` ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = due_date
                                        exp = CONV zboe_due_date( '20270131' )
                                        msg = `The day number of an Excel date cell is a date` ).
  ENDMETHOD.

  METHOD given_no_calendar_day_then_msg.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-due_date   = `31.04.2027`.
    row-cells-issue_date = `next week`.

    " ACT
    DATA(mapped) = cut->map( row ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = mapped-item-due_date
                                         msg = `A day the calendar does not have is no date` ).
    assert_finding( messages = mapped-messages
                    number   = finding-no_date
                    column   = zif_boe_migration=>column-due_date ).
    assert_finding( messages = mapped-messages
                    number   = finding-no_date
                    column   = zif_boe_migration=>column-issue_date ).
  ENDMETHOD.

  METHOD given_comma_then_amount.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-amount = `1500,5`.

    " ACT
    DATA(cheque) = cut->map( row )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = cheque-amount
                                        exp = '1500.50'
                                        msg = `An amount with a decimal comma must be converted` ).
  ENDMETHOD.

  METHOD given_thousands_sep_then_msg.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-amount = `1.500,50`.

    " ACT
    DATA(mapped) = cut->map( row ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = mapped-item-amount
                                         msg = `An amount that can be read in two ways is not guessed` ).
    assert_finding( messages = mapped-messages
                    number   = finding-no_amount
                    column   = zif_boe_migration=>column-amount ).
  ENDMETHOD.

  METHOD given_zero_amount_then_msg.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-amount = `0`.

    " ACT
    DATA(mapped) = cut->map( row ).

    " ASSERT
    assert_finding( messages = mapped-messages
                    number   = finding-amount_not_plus
                    column   = zif_boe_migration=>column-amount ).
  ENDMETHOD.

  METHOD given_empty_row_then_mandatory.
    " ACT
    DATA(mapped) = cut->map( VALUE #( row_number = 9 ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( mapped-messages )
                                        exp = 5
                                        msg = `Each of the five mandatory columns is reported once` ).
    assert_finding( messages = mapped-messages
                    number   = finding-value_missing
                    column   = zif_boe_migration=>column-due_date ).
    cl_abap_unit_assert=>assert_equals( act = mapped-messages[ 1 ]-row_number
                                        exp = 9
                                        msg = `A message names the row it is about` ).
    cl_abap_unit_assert=>assert_equals( act = mapped-messages[ 1 ]-severity
                                        exp = zif_boe_migration=>severity-error
                                        msg = `A missing mandatory value is an error` ).
    cl_abap_unit_assert=>assert_not_initial( act = mapped-messages[ 1 ]-text
                                             msg = `A message carries its text` ).
  ENDMETHOD.

  METHOD given_long_value_then_msg.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-house_bank = `NBG0001`.

    " ACT
    DATA(mapped) = cut->map( row ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = mapped-item-house_bank
                                         msg = `A value that does not fit its field must not be cut off` ).
    assert_finding( messages = mapped-messages
                    number   = finding-too_long
                    column   = zif_boe_migration=>column-house_bank ).
  ENDMETHOD.

  METHOD given_x_then_register_only.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-register_only = `x`.

    " ACT
    DATA(cheque) = cut->map( row )-item.

    " ASSERT
    cl_abap_unit_assert=>assert_true( act = cheque-is_register_only
                                      msg = `An X in column REGISTER_ONLY keeps the bill out of accounting` ).
  ENDMETHOD.

  METHOD given_other_flag_then_msg.
    " ARRANGE
    DATA(row) = valid_row( ).
    row-cells-register_only = `yes`.

    " ACT
    DATA(mapped) = cut->map( row ).

    " ASSERT
    cl_abap_unit_assert=>assert_false( act = mapped-item-is_register_only
                                       msg = `Only an X sets the flag` ).
    assert_finding( messages = mapped-messages
                    number   = finding-no_flag
                    column   = zif_boe_migration=>column-register_only ).
  ENDMETHOD.

ENDCLASS.
