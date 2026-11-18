"! <p class="shorttext synchronized" lang="EN">Converts a row of the migration file into a cheque</p>
"! A date is accepted as YYYYMMDD, DD.MM.YYYY, DD/MM/YYYY or YYYY-MM-DD, and
"! as the day number that Excel keeps in a cell formatted as a date. An amount
"! is accepted with a point or a comma in front of the decimals and without a
"! separator between the thousands.
CLASS zcl_boe_item_mapper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_item_mapper.

  PRIVATE SECTION.
    "! Digits, then optionally a point and one or two decimals.
    CONSTANTS amount_pattern TYPE string VALUE `^\d{1,15}(\.\d{1,2})?$`.
    CONSTANTS decimal_comma TYPE string VALUE `,`.
    CONSTANTS decimal_point TYPE string VALUE `.`.
    "! YYYYMMDD.
    CONSTANTS compact_date_pattern TYPE string VALUE `^\d{8}$`.
    "! YYYY-MM-DD.
    CONSTANTS iso_date_pattern TYPE string VALUE `^(\d{4})-(\d{1,2})-(\d{1,2})$`.
    "! DD.MM.YYYY and DD/MM/YYYY.
    CONSTANTS day_first_date_pattern TYPE string VALUE `^(\d{1,2})[./](\d{1,2})[./](\d{4})$`.
    "! Day number of Excel: five digits cover the years 1927 to 2173.
    CONSTANTS excel_day_pattern TYPE string VALUE `^\d{5}$`.
    "! The day before day 1 of Excel, corrected for the leap day 1900 that Excel counts and the calendar lacks.
    CONSTANTS excel_day_zero TYPE d VALUE '18991230'.
    "! Content of a cell that sets a yes/no column.
    CONSTANTS flag_set TYPE string VALUE `X`.

    TYPES:
      "! A column whose cell is taken over as text.
      BEGIN OF text_column,
        name          TYPE zboe_column_name,
        "! Keys of master data are stored in upper case.
        is_upper_case TYPE abap_bool,
      END OF text_column.
    TYPES text_column_list TYPE STANDARD TABLE OF text_column WITH EMPTY KEY.

    "! Row whose cells are being converted.
    DATA row_number TYPE zboe_row_number.
    "! Messages about the cells of that row.
    DATA messages TYPE zif_boe_migration=>messages.

    METHODS text_columns
      RETURNING VALUE(result) TYPE text_column_list.

    METHODS require_mandatory
      IMPORTING cells TYPE zif_boe_migration=>file_cells.

    METHODS texts_of
      IMPORTING cells         TYPE zif_boe_migration=>file_cells
      RETURNING VALUE(result) TYPE zif_boe_migration=>item.

    METHODS amount_of
      IMPORTING cell          TYPE string
      RETURNING VALUE(result) TYPE zboe_amount.

    METHODS date_of
      IMPORTING column        TYPE zboe_column_name
                cell          TYPE string
      RETURNING VALUE(result) TYPE d.

    "! Brings a date of any accepted format into the form YYYYMMDD.
    METHODS date_digits
      IMPORTING cell          TYPE string
      RETURNING VALUE(result) TYPE string.

    METHODS is_calendar_date
      IMPORTING digits        TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS flag_of
      IMPORTING cell          TYPE string
      RETURNING VALUE(result) TYPE abap_bool.

    "! Keeps the message that a MESSAGE statement has just built.
    METHODS add_message
      IMPORTING column TYPE zboe_column_name
                text   TYPE string.

ENDCLASS.



CLASS zcl_boe_item_mapper IMPLEMENTATION.

  METHOD zif_boe_item_mapper~map.
    row_number = row-row_number.
    CLEAR messages.

    require_mandatory( row-cells ).

    result-item = texts_of( row-cells ).
    result-item-row_number       = row-row_number.
    " customer numbers that are numbers are stored with leading zeros
    result-item-customer         = |{ result-item-customer ALPHA = IN }|.
    result-item-amount           = amount_of( row-cells-amount ).
    result-item-due_date         = date_of( column = zif_boe_migration=>column-due_date
                                            cell   = row-cells-due_date ).
    result-item-issue_date       = date_of( column = zif_boe_migration=>column-issue_date
                                            cell   = row-cells-issue_date ).
    result-item-is_register_only = flag_of( row-cells-register_only ).

    IF row-cells-target_status IS INITIAL.
      result-item-target_status = zif_boe_status_rules=>status-in_portfolio.
    ENDIF.

    result-messages = messages.
  ENDMETHOD.

  METHOD text_columns.
    result = VALUE #( ( name = zif_boe_migration=>column-boe_number )
                      ( name = zif_boe_migration=>column-customer            is_upper_case = abap_true )
                      ( name = zif_boe_migration=>column-currency            is_upper_case = abap_true )
                      ( name = zif_boe_migration=>column-target_status )
                      ( name = zif_boe_migration=>column-drawer_name )
                      ( name = zif_boe_migration=>column-drawee_bank_country is_upper_case = abap_true )
                      ( name = zif_boe_migration=>column-drawee_bank )
                      ( name = zif_boe_migration=>column-drawee_bank_name )
                      ( name = zif_boe_migration=>column-drawee_account )
                      ( name = zif_boe_migration=>column-house_bank          is_upper_case = abap_true )
                      ( name = zif_boe_migration=>column-house_bank_account  is_upper_case = abap_true )
                      ( name = zif_boe_migration=>column-legacy_reference )
                      ( name = zif_boe_migration=>column-note ) ).
  ENDMETHOD.

  METHOD require_mandatory.
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE zif_boe_migration=>mandatory_column TO FIELD-SYMBOL(<column>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      ASSIGN COMPONENT <column> OF STRUCTURE cells TO FIELD-SYMBOL(<cell>).
      IF sy-subrc = 0 AND <cell> IS INITIAL.
        MESSAGE e054(zboe) WITH <column> INTO DATA(text).
        add_message( column = <column>
                     text   = text ).
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD texts_of.
    LOOP AT text_columns( ) INTO DATA(column).
      " cells and cheque name their components after the columns of the template
      ASSIGN COMPONENT column-name OF STRUCTURE cells TO FIELD-SYMBOL(<cell>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT column-name OF STRUCTURE result TO FIELD-SYMBOL(<field>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(value) = COND string( WHEN column-is_upper_case = abap_true
                                 THEN to_upper( <cell> )
                                 ELSE <cell> ).
      <field> = value.

      " the field cut the value off: half a key or half a name is worse than none
      IF CONV string( <field> ) <> value.
        CLEAR <field>.
        MESSAGE e050(zboe) WITH column-name value INTO DATA(text).
        add_message( column = column-name
                     text   = text ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD amount_of.
    IF cell IS INITIAL.
      " reported as a missing mandatory value
      RETURN.
    ENDIF.

    DATA(number) = replace( val  = cell
                            sub  = decimal_comma
                            with = decimal_point ).
    IF NOT matches( val  = number
                    pcre = amount_pattern ).
      MESSAGE e052(zboe) WITH zif_boe_migration=>column-amount cell INTO DATA(not_an_amount).
      add_message( column = zif_boe_migration=>column-amount
                   text   = not_an_amount ).
      RETURN.
    ENDIF.

    result = number.
    IF result <= 0.
      MESSAGE e055(zboe) INTO DATA(not_positive).
      add_message( column = zif_boe_migration=>column-amount
                   text   = not_positive ).
    ENDIF.
  ENDMETHOD.

  METHOD date_of.
    IF cell IS INITIAL.
      RETURN.
    ENDIF.

    DATA(digits) = date_digits( cell ).
    IF is_calendar_date( digits ) = abap_false.
      MESSAGE e051(zboe) WITH column cell INTO DATA(text).
      add_message( column = column
                   text   = text ).
      RETURN.
    ENDIF.

    result = digits.
  ENDMETHOD.

  METHOD date_digits.
    IF matches( val  = cell
                pcre = compact_date_pattern ).
      result = cell.
      RETURN.
    ENDIF.

    FIND PCRE iso_date_pattern IN cell SUBMATCHES DATA(year) DATA(month) DATA(day).
    IF sy-subrc <> 0.
      FIND PCRE day_first_date_pattern IN cell SUBMATCHES day month year.
    ENDIF.
    IF sy-subrc = 0.
      result = |{ year }{ month WIDTH = 2 ALIGN = RIGHT PAD = '0' }{ day WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
      RETURN.
    ENDIF.

    IF matches( val  = cell
                pcre = excel_day_pattern ).
      result = CONV d( excel_day_zero + CONV i( cell ) ).
    ENDIF.
  ENDMETHOD.

  METHOD is_calendar_date.
    DATA(date) = CONV d( digits ).

    " date arithmetic does not know a day that the calendar lacks: a 31 April does not come back
    DATA(next_day) = CONV d( date + 1 ).
    DATA(same_day) = CONV d( next_day - 1 ).

    result = xsdbool( date IS NOT INITIAL AND same_day = date ).
  ENDMETHOD.

  METHOD flag_of.
    CASE to_upper( cell ).
      WHEN ``.
        result = abap_false.
      WHEN flag_set.
        result = abap_true.
      WHEN OTHERS.
        MESSAGE e053(zboe) WITH zif_boe_migration=>column-register_only cell INTO DATA(text).
        add_message( column = zif_boe_migration=>column-register_only
                     text   = text ).
    ENDCASE.
  ENDMETHOD.

  METHOD add_message.
    INSERT VALUE #( row_number = row_number
                    column     = column
                    severity   = sy-msgty
                    id         = sy-msgid
                    number     = sy-msgno
                    variable_1 = sy-msgv1
                    variable_2 = sy-msgv2
                    variable_3 = sy-msgv3
                    variable_4 = sy-msgv4
                    text       = text )
           INTO TABLE messages.
  ENDMETHOD.

ENDCLASS.
