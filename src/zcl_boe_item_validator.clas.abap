"! <p class="shorttext synchronized" lang="EN">Checks the cheques of a migration file</p>
"! Reads the master data for the whole file first and then checks cheque by
"! cheque, so that the number of database accesses does not grow with the file.
CLASS zcl_boe_item_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_item_validator.

    "! @parameter master_data  | Master data of financial accounting
    "! @parameter status_rules | Status rules of a bill of exchange
    METHODS constructor
      IMPORTING master_data  TYPE REF TO zif_boe_master_data
                status_rules TYPE REF TO zif_boe_status_rules.

  PRIVATE SECTION.
    "! Decimal places of the amount of a cheque. An amount in a currency with
    "! other decimal places would be stored shifted.
    CONSTANTS supported_decimals TYPE i VALUE 2.

    TYPES:
      "! What makes two rows the same cheque, and the row that had it first.
      BEGIN OF cheque_identity,
        boe_number  TYPE zboe_number,
        customer    TYPE zboe_customer,
        drawee_bank TYPE zboe_bank,
        row_number  TYPE zboe_row_number,
      END OF cheque_identity.
    TYPES cheque_identities TYPE HASHED TABLE OF cheque_identity
                            WITH UNIQUE KEY boe_number customer drawee_bank.

    DATA master_data TYPE REF TO zif_boe_master_data.
    DATA status_rules TYPE REF TO zif_boe_status_rules.

    "! Company code of the file that is being checked.
    DATA company_code TYPE zboe_company_code.
    "! Master data of the file that is being checked.
    DATA customers TYPE zif_boe_master_data=>customer_keys.
    DATA currencies TYPE zif_boe_master_data=>currency_infos.
    DATA banks TYPE zif_boe_master_data=>bank_keys.
    DATA accounts TYPE zif_boe_master_data=>account_keys.
    "! Cheques of the file that were checked already.
    DATA seen_cheques TYPE cheque_identities.
    "! Row that is being checked.
    DATA row_number TYPE zboe_row_number.
    "! Findings about the file that is being checked.
    DATA messages TYPE zif_boe_migration=>messages.

    METHODS read_master_data
      IMPORTING items TYPE zif_boe_migration=>items.

    METHODS customers_of
      IMPORTING items         TYPE zif_boe_migration=>items
      RETURNING VALUE(result) TYPE zif_boe_master_data=>customer_keys.

    METHODS drawee_banks_of
      IMPORTING items         TYPE zif_boe_migration=>items
      RETURNING VALUE(result) TYPE zif_boe_master_data=>bank_keys.

    METHODS check_dates
      IMPORTING item TYPE zif_boe_migration=>item.

    METHODS check_status
      IMPORTING item TYPE zif_boe_migration=>item.

    "! Tells whether a bill in a status lies at a bank.
    METHODS is_deposited
      IMPORTING status        TYPE zboe_status
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS check_duplicate
      IMPORTING item TYPE zif_boe_migration=>item.

    METHODS check_customer
      IMPORTING item TYPE zif_boe_migration=>item.

    METHODS check_currency
      IMPORTING item TYPE zif_boe_migration=>item.

    METHODS check_house_bank
      IMPORTING item TYPE zif_boe_migration=>item.

    METHODS check_drawee_bank
      IMPORTING item TYPE zif_boe_migration=>item.

    "! Keeps the message that a MESSAGE statement has just built.
    METHODS add_message
      IMPORTING column TYPE zboe_column_name
                text   TYPE string.

ENDCLASS.



CLASS zcl_boe_item_validator IMPLEMENTATION.

  METHOD constructor.
    me->master_data  = master_data.
    me->status_rules = status_rules.
  ENDMETHOD.

  METHOD zif_boe_item_validator~validate.
    me->company_code = company_code.
    CLEAR seen_cheques.
    CLEAR messages.

    read_master_data( items ).

    LOOP AT items INTO DATA(item).
      row_number = item-row_number.

      check_dates( item ).
      check_status( item ).
      check_duplicate( item ).
      check_customer( item ).
      check_currency( item ).
      check_house_bank( item ).
      check_drawee_bank( item ).
    ENDLOOP.

    result = messages.
  ENDMETHOD.

  METHOD read_master_data.
    customers  = master_data->customers_in_company( company_code = company_code
                                                    customers    = customers_of( items ) ).
    currencies = master_data->currencies( ).
    banks      = master_data->existing_banks( drawee_banks_of( items ) ).
    accounts   = master_data->house_bank_accounts( company_code ).
  ENDMETHOD.

  METHOD customers_of.
    LOOP AT items INTO DATA(item) WHERE customer IS NOT INITIAL.
      " a customer with several cheques is asked for once
      INSERT VALUE #( customer = item-customer ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD drawee_banks_of.
    LOOP AT items INTO DATA(item) WHERE drawee_bank_country IS NOT INITIAL AND drawee_bank IS NOT INITIAL.
      INSERT VALUE #( bank_country = item-drawee_bank_country
                      bank         = item-drawee_bank )
             INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_dates.
    IF item-due_date IS INITIAL OR item-issue_date IS INITIAL OR item-due_date >= item-issue_date.
      RETURN.
    ENDIF.

    DATA(due_date) = |{ item-due_date DATE = ISO }|.
    DATA(issue_date) = |{ item-issue_date DATE = ISO }|.
    MESSAGE e060(zboe) WITH due_date issue_date INTO DATA(text).
    add_message( column = zif_boe_migration=>column-due_date
                 text   = text ).
  ENDMETHOD.

  METHOD check_status.
    IF item-target_status IS INITIAL.
      RETURN.
    ENDIF.

    IF status_rules->is_migration_target( item-target_status ) = abap_false.
      MESSAGE e061(zboe) WITH item-target_status INTO DATA(not_possible).
      add_message( column = zif_boe_migration=>column-target_status
                   text   = not_possible ).
      RETURN.
    ENDIF.

    IF is_deposited( item-target_status ) = abap_true
       AND ( item-house_bank IS INITIAL OR item-house_bank_account IS INITIAL ).
      MESSAGE e062(zboe) WITH item-target_status INTO DATA(no_house_bank).
      add_message( column = zif_boe_migration=>column-house_bank
                   text   = no_house_bank ).
    ENDIF.
  ENDMETHOD.

  METHOD is_deposited.
    result = xsdbool( status = zif_boe_status_rules=>status-at_bank_for_collection
                   OR status = zif_boe_status_rules=>status-at_bank_as_collateral ).
  ENDMETHOD.

  METHOD check_duplicate.
    IF item-boe_number IS INITIAL OR item-customer IS INITIAL.
      RETURN.
    ENDIF.

    INSERT VALUE #( boe_number  = item-boe_number
                    customer    = item-customer
                    drawee_bank = item-drawee_bank
                    row_number  = item-row_number )
           INTO TABLE seen_cheques.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    DATA(customer) = |{ item-customer ALPHA = OUT }|.
    DATA(first_row) = |{ seen_cheques[ boe_number  = item-boe_number
                                       customer    = item-customer
                                       drawee_bank = item-drawee_bank ]-row_number }|.
    MESSAGE e063(zboe) WITH item-boe_number customer first_row INTO DATA(text).
    add_message( column = zif_boe_migration=>column-boe_number
                 text   = text ).
  ENDMETHOD.

  METHOD check_customer.
    IF item-customer IS INITIAL OR line_exists( customers[ customer = item-customer ] ).
      RETURN.
    ENDIF.

    DATA(customer) = |{ item-customer ALPHA = OUT }|.
    MESSAGE e064(zboe) WITH customer company_code INTO DATA(text).
    add_message( column = zif_boe_migration=>column-customer
                 text   = text ).
  ENDMETHOD.

  METHOD check_currency.
    IF item-currency IS INITIAL.
      RETURN.
    ENDIF.

    IF NOT line_exists( currencies[ currency = item-currency ] ).
      MESSAGE e065(zboe) WITH item-currency INTO DATA(unknown).
      add_message( column = zif_boe_migration=>column-currency
                   text   = unknown ).
      RETURN.
    ENDIF.

    IF currencies[ currency = item-currency ]-decimals <> supported_decimals.
      MESSAGE e066(zboe) WITH item-currency INTO DATA(unsupported).
      add_message( column = zif_boe_migration=>column-currency
                   text   = unsupported ).
    ENDIF.
  ENDMETHOD.

  METHOD check_house_bank.
    IF item-house_bank IS INITIAL.
      RETURN.
    ENDIF.

    IF NOT line_exists( accounts[ house_bank = item-house_bank ] ).
      MESSAGE e067(zboe) WITH item-house_bank company_code INTO DATA(no_house_bank).
      add_message( column = zif_boe_migration=>column-house_bank
                   text   = no_house_bank ).
      RETURN.
    ENDIF.

    IF item-house_bank_account IS NOT INITIAL
       AND NOT line_exists( accounts[ house_bank         = item-house_bank
                                      house_bank_account = item-house_bank_account ] ).
      MESSAGE e068(zboe) WITH item-house_bank_account item-house_bank INTO DATA(no_account).
      add_message( column = zif_boe_migration=>column-house_bank_account
                   text   = no_account ).
    ENDIF.
  ENDMETHOD.

  METHOD check_drawee_bank.
    IF item-drawee_bank IS INITIAL.
      RETURN.
    ENDIF.

    IF item-drawee_bank_country IS INITIAL.
      " a bank key is unique within a country only
      MESSAGE e070(zboe) INTO DATA(no_country).
      add_message( column = zif_boe_migration=>column-drawee_bank_country
                   text   = no_country ).
      RETURN.
    ENDIF.

    IF NOT line_exists( banks[ bank_country = item-drawee_bank_country
                               bank         = item-drawee_bank ] ).
      " a warning: the drawee bank is information on the bill, accounting does not post to it
      MESSAGE w069(zboe) WITH item-drawee_bank item-drawee_bank_country INTO DATA(not_in_master_data).
      add_message( column = zif_boe_migration=>column-drawee_bank
                   text   = not_in_master_data ).
    ENDIF.
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
