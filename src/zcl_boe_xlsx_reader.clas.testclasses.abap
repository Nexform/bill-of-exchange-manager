*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Builds migration files in memory</p>
"! A workbook with one sheet added whose rows the test supplies, written with
"! the same library the reader reads with.
CLASS lth_workbook DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    TYPES:
      "! Columns A to F of a row.
      BEGIN OF row,
        a TYPE string,
        b TYPE string,
        c TYPE string,
        d TYPE string,
        e TYPE string,
        f TYPE string,
      END OF row.
    TYPES rows TYPE STANDARD TABLE OF row WITH EMPTY KEY.

    "! Creates the workbook.
    "!
    "! @parameter sheet_name | Name of the sheet that gets the rows
    "! @parameter rows       | Rows of the sheet from row 1
    "! @parameter result     | The workbook as a file
    CLASS-METHODS with_sheet
      IMPORTING sheet_name    TYPE string DEFAULT `Cheques`
                rows          TYPE rows
      RETURNING VALUE(result) TYPE xstring.

    "! Row 1 of a sheet with the mandatory columns in the order of the template.
    "!
    "! @parameter result | The header row
    CLASS-METHODS header
      RETURNING VALUE(result) TYPE row.
ENDCLASS.


CLASS lth_workbook IMPLEMENTATION.

  METHOD with_sheet.
    DATA(document) = xco_cp_xlsx=>document->empty( )->write_access( ).

    document->get_workbook( )->add_new_sheet( sheet_name
      )->select( xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( )
      )->row_stream(
      )->operation->write_from( REF #( rows )
      )->execute( ).

    result = document->get_file_content( ).
  ENDMETHOD.

  METHOD header.
    result = VALUE #( a = `BOE_NUMBER`
                      b = `CUSTOMER`
                      c = `AMOUNT`
                      d = `CURRENCY`
                      e = `DUE_DATE`
                      f = `NOTE` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_xlsx_reader DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    "! Message numbers of ZBOE that tell the unusable files apart.
    CONSTANTS:
      BEGIN OF failure,
        no_workbook    TYPE symsgno VALUE '040',
        sheet_missing  TYPE symsgno VALUE '041',
        column_missing TYPE symsgno VALUE '042',
        no_cheques     TYPE symsgno VALUE '043',
      END OF failure.

    DATA cut TYPE REF TO zif_boe_xlsx_reader.

    METHODS setup.

    "! Reads a file that must be rejected and returns the exception.
    METHODS rejection_of
      IMPORTING file_content  TYPE xstring
      RETURNING VALUE(result) TYPE REF TO zcx_boe_file.

    METHODS given_cheques_then_rows        FOR TESTING RAISING cx_static_check.
    METHODS given_gap_then_row_number_kept FOR TESTING RAISING cx_static_check.
    METHODS given_other_order_then_by_name FOR TESTING RAISING cx_static_check.
    METHODS given_unknown_column_then_skip FOR TESTING RAISING cx_static_check.
    METHODS given_blanks_then_trimmed      FOR TESTING RAISING cx_static_check.
    METHODS given_no_workbook_then_error   FOR TESTING RAISING cx_static_check.
    METHODS given_no_sheet_then_error      FOR TESTING RAISING cx_static_check.
    METHODS given_no_column_then_error     FOR TESTING RAISING cx_static_check.
    METHODS given_header_only_then_error   FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltc_xlsx_reader IMPLEMENTATION.

  METHOD setup.
    cut = NEW zcl_boe_xlsx_reader( ).
  ENDMETHOD.

  METHOD rejection_of.
    TRY.
        cut->read( file_content ).
        cl_abap_unit_assert=>fail( msg = `An unusable file must raise zcx_boe_file` ).
      CATCH zcx_boe_file INTO result.
    ENDTRY.
  ENDMETHOD.

  METHOD given_cheques_then_rows.
    " ARRANGE
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( lth_workbook=>header( ) )
                   ( a = `00123456` b = `100001` c = `1500.50` d = `EUR` e = `31.01.2027` )
                   ( a = `00123457` b = `100002` c = `200` d = `EUR` e = `28.02.2027` f = `Late` ) ) ).

    " ACT
    DATA(rows) = cut->read( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( rows )
                                        exp = 2
                                        msg = `Every row below row 1 is a cheque` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-row_number
                                        exp = 2
                                        msg = `The first cheque stands in row 2 of the sheet` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells-boe_number
                                        exp = `00123456`
                                        msg = `A cell is text: leading zeros of a cheque number stay` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-cells-note
                                        exp = `Late`
                                        msg = `The last column of the row must be read` ).
  ENDMETHOD.

  METHOD given_gap_then_row_number_kept.
    " ARRANGE
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( lth_workbook=>header( ) )
                   ( a = `1` b = `100001` c = `10` d = `EUR` e = `20270131` )
                   ( )
                   ( a = `2` b = `100001` c = `20` d = `EUR` e = `20270131` ) ) ).

    " ACT
    DATA(rows) = cut->read( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( rows )
                                        exp = 2
                                        msg = `An empty row between cheques is no cheque` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 2 ]-row_number
                                        exp = 4
                                        msg = `The row number is the row of the sheet, gaps included` ).
  ENDMETHOD.

  METHOD given_other_order_then_by_name.
    " ARRANGE
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( a = `DUE_DATE` b = `CURRENCY` c = `BOE_NUMBER` d = `AMOUNT` e = `CUSTOMER` )
                   ( a = `20270131` b = `EUR` c = `00123456` d = `1500.50` e = `100001` ) ) ).

    " ACT
    DATA(rows) = cut->read( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells-boe_number
                                        exp = `00123456`
                                        msg = `A column is found by its name in row 1, not by its position` ).
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells-customer
                                        exp = `100001`
                                        msg = `A column is found by its name in row 1, not by its position` ).
  ENDMETHOD.

  METHOD given_unknown_column_then_skip.
    " ARRANGE
    DATA(header) = lth_workbook=>header( ).
    header-f = `MY_REMARKS`.
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( header )
                   ( a = `1` b = `100001` c = `10` d = `EUR` e = `20270131` f = `checked` )
                   ( f = `only a remark` ) ) ).

    " ACT
    DATA(rows) = cut->read( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( rows )
                                        exp = 1
                                        msg = `A row with values in unknown columns only is no cheque` ).
    cl_abap_unit_assert=>assert_initial( act = rows[ 1 ]-cells-note
                                         msg = `A column the template does not know must not fill a cell` ).
  ENDMETHOD.

  METHOD given_blanks_then_trimmed.
    " ARRANGE
    DATA(header) = lth_workbook=>header( ).
    header-a = ` boe_number `.
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( header )
                   ( a = `  A 1  ` b = `100001` c = `10` d = `EUR` e = `20270131` ) ) ).

    " ACT
    DATA(rows) = cut->read( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = rows[ 1 ]-cells-boe_number
                                        exp = `A 1`
                                        msg = `Blanks around a value go, blanks inside it stay` ).
  ENDMETHOD.

  METHOD given_no_workbook_then_error.
    " ACT
    DATA(error) = rejection_of( CONV xstring( 'FFFEFDFC' ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                        exp = failure-no_workbook
                                        msg = `Wrong failure kind - expected no_workbook` ).
  ENDMETHOD.

  METHOD given_no_sheet_then_error.
    " ARRANGE
    DATA(file) = lth_workbook=>with_sheet( sheet_name = `Data`
                                           rows       = VALUE #( ( lth_workbook=>header( ) ) ) ).

    " ACT
    DATA(error) = rejection_of( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                        exp = failure-sheet_missing
                                        msg = `Wrong failure kind - expected sheet_missing` ).
  ENDMETHOD.

  METHOD given_no_column_then_error.
    " ARRANGE
    DATA(header) = lth_workbook=>header( ).
    header-e = `MATURITY`.
    DATA(file) = lth_workbook=>with_sheet( VALUE #(
                   ( header )
                   ( a = `1` b = `100001` c = `10` d = `EUR` e = `20270131` ) ) ).

    " ACT
    DATA(error) = rejection_of( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                        exp = failure-column_missing
                                        msg = `Wrong failure kind - expected column_missing` ).
    cl_abap_unit_assert=>assert_equals( act = error->if_t100_dyn_msg~msgv1
                                        exp = 'DUE_DATE'
                                        msg = `The message must name the column that is missing` ).
  ENDMETHOD.

  METHOD given_header_only_then_error.
    " ARRANGE
    DATA(file) = lth_workbook=>with_sheet( VALUE #( ( lth_workbook=>header( ) ) ) ).

    " ACT
    DATA(error) = rejection_of( file ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                        exp = failure-no_cheques
                                        msg = `Wrong failure kind - expected no_cheques` ).
  ENDMETHOD.

ENDCLASS.
