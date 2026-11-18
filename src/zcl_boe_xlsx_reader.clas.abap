"! <p class="shorttext synchronized" lang="EN">Reads the cheques of a migration file</p>
"! Reads the workbook with the XLSX library of XCO. Of sheet Cheques the
"! columns A to Z are looked at, which leaves room for nine columns next to
"! those of the template.
CLASS zcl_boe_xlsx_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_xlsx_reader.

  PRIVATE SECTION.
    "! Name of the sheet with the cheques in the template.
    CONSTANTS sheet_name TYPE string VALUE `Cheques`.
    CONSTANTS first_column TYPE string VALUE `A`.
    CONSTANTS last_column TYPE string VALUE `Z`.
    "! Row of the sheet that names the columns.
    CONSTANTS header_row TYPE i VALUE 1.
    CONSTANTS first_cheque_row TYPE i VALUE 2.

    TYPES:
      "! The cells of columns A to Z of one row, in the order of the sheet.
      BEGIN OF sheet_row,
        column_a TYPE string,
        column_b TYPE string,
        column_c TYPE string,
        column_d TYPE string,
        column_e TYPE string,
        column_f TYPE string,
        column_g TYPE string,
        column_h TYPE string,
        column_i TYPE string,
        column_j TYPE string,
        column_k TYPE string,
        column_l TYPE string,
        column_m TYPE string,
        column_n TYPE string,
        column_o TYPE string,
        column_p TYPE string,
        column_q TYPE string,
        column_r TYPE string,
        column_s TYPE string,
        column_t TYPE string,
        column_u TYPE string,
        column_v TYPE string,
        column_w TYPE string,
        column_x TYPE string,
        column_y TYPE string,
        column_z TYPE string,
      END OF sheet_row.
    TYPES sheet_rows TYPE STANDARD TABLE OF sheet_row WITH EMPTY KEY.

    TYPES:
      "! Where a column of the template stands in the sheet.
      BEGIN OF column_position,
        name     TYPE zboe_column_name,
        position TYPE i,
      END OF column_position.
    TYPES column_positions TYPE SORTED TABLE OF column_position WITH UNIQUE KEY name.

    METHODS sheet_rows_of
      IMPORTING file_content  TYPE xstring
      RETURNING VALUE(result) TYPE sheet_rows
      RAISING   zcx_boe_file.

    METHODS columns_a_to_z
      RETURNING VALUE(result) TYPE REF TO if_xco_xlsx_slc_pattern.

    METHODS columns_in
      IMPORTING header        TYPE sheet_row
      RETURNING VALUE(result) TYPE column_positions
      RAISING   zcx_boe_file.

    METHODS is_template_column
      IMPORTING name          TYPE zboe_column_name
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS assert_mandatory_columns
      IMPORTING columns TYPE column_positions
      RAISING   zcx_boe_file.

    METHODS cells_of
      IMPORTING sheet_row     TYPE sheet_row
                columns       TYPE column_positions
      RETURNING VALUE(result) TYPE zif_boe_migration=>file_cells.

ENDCLASS.



CLASS zcl_boe_xlsx_reader IMPLEMENTATION.

  METHOD zif_boe_xlsx_reader~read.
    DATA(sheet) = sheet_rows_of( file_content ).
    DATA(columns) = columns_in( VALUE #( sheet[ header_row ] OPTIONAL ) ).

    LOOP AT sheet INTO DATA(sheet_row) FROM first_cheque_row.
      DATA(row_number) = sy-tabix.
      DATA(cells) = cells_of( sheet_row = sheet_row
                              columns   = columns ).

      " a row without any value is a gap between cheques or formatting left over below them
      IF cells IS NOT INITIAL.
        INSERT VALUE #( row_number = row_number
                        cells      = cells )
               INTO TABLE result.
      ENDIF.
    ENDLOOP.

    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zcx_boe_file
        MESSAGE e043(zboe) WITH sheet_name.
    ENDIF.
  ENDMETHOD.

  METHOD sheet_rows_of.
    TRY.
        DATA(worksheet) = xco_cp_xlsx=>document->for_file_content( file_content
          )->read_access( )->get_workbook( )->worksheet->for_name( sheet_name ).

        IF worksheet->exists( ) = abap_false.
          RAISE EXCEPTION TYPE zcx_boe_file
            MESSAGE e041(zboe) WITH sheet_name.
        ENDIF.

        " every cell as text: what a cell means is decided by the mapper, not by its Excel format
        worksheet->select( columns_a_to_z( )
          )->row_stream(
          )->operation->write_to( REF #( result )
          )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->if_xco_xlsx_ra_operation~execute( ).

      CATCH cx_xco_runtime_exception INTO DATA(unreadable).
        RAISE EXCEPTION TYPE zcx_boe_file
          MESSAGE e040(zboe)
          EXPORTING
            previous = unreadable.
    ENDTRY.
  ENDMETHOD.

  METHOD columns_a_to_z.
    result = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( first_column )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( last_column )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( header_row )
      )->get_pattern( ).
  ENDMETHOD.

  METHOD columns_in.
    DO.
      DATA(position) = sy-index.
      ASSIGN COMPONENT position OF STRUCTURE header TO FIELD-SYMBOL(<title>).
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      DATA(name) = CONV zboe_column_name( to_upper( condense( <title> ) ) ).
      IF is_template_column( name ) = abap_true.
        " a name that stands twice in row 1 counts where it stands first
        INSERT VALUE #( name     = name
                        position = position )
               INTO TABLE result.
      ENDIF.
    ENDDO.

    assert_mandatory_columns( result ).
  ENDMETHOD.

  METHOD is_template_column.
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE zif_boe_migration=>column TO FIELD-SYMBOL(<column>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      IF <column> = name.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD assert_mandatory_columns.
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE zif_boe_migration=>mandatory_column TO FIELD-SYMBOL(<mandatory>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      IF NOT line_exists( columns[ name = <mandatory> ] ).
        RAISE EXCEPTION TYPE zcx_boe_file
          MESSAGE e042(zboe) WITH <mandatory> sheet_name.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD cells_of.
    LOOP AT columns INTO DATA(column).
      ASSIGN COMPONENT column-position OF STRUCTURE sheet_row TO FIELD-SYMBOL(<cell>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " the components of the result carry the names of the template columns
      ASSIGN COMPONENT column-name OF STRUCTURE result TO FIELD-SYMBOL(<value>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " blanks around a value are typing accidents; blanks inside it are kept
      <value> = condense( val  = <cell>
                          from = `` ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
