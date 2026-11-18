*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Master data of a small company, held in memory</p>
"! One customer, the euro and the yen, one bank and one house bank account. A
"! test that needs other master data changes the public tables before it acts.
CLASS ltd_master_data DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_boe_master_data.

    DATA known_customers TYPE zif_boe_master_data=>customer_keys.
    DATA known_currencies TYPE zif_boe_master_data=>currency_infos.
    DATA known_banks TYPE zif_boe_master_data=>bank_keys.
    DATA known_accounts TYPE zif_boe_master_data=>account_keys.
    "! Company code the customers were asked for.
    DATA asked_company_code TYPE zboe_company_code.

    METHODS constructor.
ENDCLASS.


CLASS ltd_master_data IMPLEMENTATION.

  METHOD constructor.
    known_customers  = VALUE #( ( customer = '0000100001' ) ).
    known_currencies = VALUE #( ( currency = 'EUR' decimals = 2 )
                                ( currency = 'JPY' decimals = 0 ) ).
    known_banks      = VALUE #( ( bank_country = 'GR' bank = '0110' ) ).
    known_accounts   = VALUE #( ( house_bank = 'NBG01' house_bank_account = 'EUR01' ) ).
  ENDMETHOD.

  METHOD zif_boe_master_data~existing_company_codes.
    result = company_codes.
  ENDMETHOD.

  METHOD zif_boe_master_data~customers_in_company.
    asked_company_code = company_code.

    LOOP AT customers INTO DATA(customer).
      IF line_exists( known_customers[ customer = customer-customer ] ).
        INSERT customer INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_boe_master_data~currencies.
    result = known_currencies.
  ENDMETHOD.

  METHOD zif_boe_master_data~existing_banks.
    LOOP AT banks INTO DATA(bank).
      IF line_exists( known_banks[ bank_country = bank-bank_country
                                   bank         = bank-bank ] ).
        INSERT bank INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_boe_master_data~house_bank_accounts.
    result = known_accounts.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_item_validator DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    "! Message numbers of ZBOE that the check of the cheques reports.
    CONSTANTS:
      BEGIN OF finding,
        due_before_issue    TYPE symsgno VALUE '060',
        status_not_possible TYPE symsgno VALUE '061',
        house_bank_needed   TYPE symsgno VALUE '062',
        cheque_twice        TYPE symsgno VALUE '063',
        customer_unknown    TYPE symsgno VALUE '064',
        currency_unknown    TYPE symsgno VALUE '065',
        decimals_unsupp     TYPE symsgno VALUE '066',
        house_bank_unknown  TYPE symsgno VALUE '067',
        account_unknown     TYPE symsgno VALUE '068',
        bank_unknown        TYPE symsgno VALUE '069',
        bank_country_needed TYPE symsgno VALUE '070',
      END OF finding.

    CONSTANTS company_code TYPE zboe_company_code VALUE 'GR01'.

    DATA master_data TYPE REF TO ltd_master_data.
    DATA cut TYPE REF TO zif_boe_item_validator.

    METHODS setup.

    "! A cheque that passes every check against the master data of the double.
    METHODS valid_cheque
      RETURNING VALUE(result) TYPE zif_boe_migration=>item.

    "! Checks a file with one cheque.
    METHODS findings_about
      IMPORTING cheque        TYPE zif_boe_migration=>item
      RETURNING VALUE(result) TYPE zif_boe_migration=>messages.

    "! Asserts that the check reported exactly one message, and which.
    METHODS assert_only_finding
      IMPORTING messages TYPE zif_boe_migration=>messages
                number   TYPE symsgno.

    METHODS given_valid_cheque_then_no_msg FOR TESTING.
    METHODS given_no_values_then_no_msg    FOR TESTING.
    METHODS given_due_before_issue_then_ms FOR TESTING.
    METHODS given_final_status_then_msg    FOR TESTING.
    METHODS given_deposit_no_bank_then_msg FOR TESTING.
    METHODS given_cheque_twice_then_msg    FOR TESTING.
    METHODS given_other_bank_then_no_dup   FOR TESTING.
    METHODS given_unknown_customer_then_ms FOR TESTING.
    METHODS given_unknown_currency_then_ms FOR TESTING.
    METHODS given_yen_then_msg             FOR TESTING.
    METHODS given_unknown_house_bank_then  FOR TESTING.
    METHODS given_unknown_account_then_msg FOR TESTING.
    METHODS given_unknown_bank_then_warn   FOR TESTING.
    METHODS given_bank_no_country_then_msg FOR TESTING.
    METHODS when_checked_then_own_company  FOR TESTING.
    METHODS when_second_file_then_fresh    FOR TESTING.

ENDCLASS.


CLASS ltc_item_validator IMPLEMENTATION.

  METHOD setup.
    master_data = NEW #( ).
    cut = NEW zcl_boe_item_validator( master_data  = master_data
                                      status_rules = NEW zcl_boe_status_rules( ) ).
  ENDMETHOD.

  METHOD valid_cheque.
    result = VALUE #( row_number          = 2
                      boe_number          = '00123456'
                      customer            = '0000100001'
                      amount              = '1500.50'
                      currency            = 'EUR'
                      due_date            = '20270131'
                      issue_date          = '20261130'
                      target_status       = zif_boe_status_rules=>status-at_bank_for_collection
                      drawee_bank_country = 'GR'
                      drawee_bank         = '0110'
                      house_bank          = 'NBG01'
                      house_bank_account  = 'EUR01' ).
  ENDMETHOD.

  METHOD findings_about.
    result = cut->validate( company_code = company_code
                            items        = VALUE #( ( cheque ) ) ).
  ENDMETHOD.

  METHOD assert_only_finding.
    cl_abap_unit_assert=>assert_equals( act = lines( messages )
                                        exp = 1
                                        msg = `Exactly one finding was expected` ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-number
                                        exp = number
                                        msg = `Wrong finding` ).
  ENDMETHOD.

  METHOD given_valid_cheque_then_no_msg.
    " ACT
    DATA(messages) = findings_about( valid_cheque( ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = messages
                                         msg = `A cheque whose master data exists has no finding` ).
  ENDMETHOD.

  METHOD given_no_values_then_no_msg.
    " ACT
    DATA(messages) = findings_about( VALUE #( row_number = 2 ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial(
      act = messages
      msg = `Values that are missing were reported by the conversion and are not reported again` ).
  ENDMETHOD.

  METHOD given_due_before_issue_then_ms.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-due_date = '20261031'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-due_before_issue ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-row_number
                                        exp = 2
                                        msg = `A finding names the row of its cheque` ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-column
                                        exp = zif_boe_migration=>column-due_date
                                        msg = `A finding names the column to correct` ).
  ENDMETHOD.

  METHOD given_final_status_then_msg.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-target_status = zif_boe_status_rules=>status-collected.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-status_not_possible ).
  ENDMETHOD.

  METHOD given_deposit_no_bank_then_msg.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    CLEAR cheque-house_bank_account.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-house_bank_needed ).
  ENDMETHOD.

  METHOD given_cheque_twice_then_msg.
    " ARRANGE
    DATA(again) = valid_cheque( ).
    again-row_number = 5.

    " ACT
    DATA(messages) = cut->validate( company_code = company_code
                                    items        = VALUE #( ( valid_cheque( ) ) ( again ) ) ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-cheque_twice ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-row_number
                                        exp = 5
                                        msg = `The later row is the one to correct` ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-variable_3
                                        exp = '2'
                                        msg = `The finding names the row that has the cheque already` ).
  ENDMETHOD.

  METHOD given_other_bank_then_no_dup.
    " ARRANGE
    master_data->known_banks = VALUE #( ( bank_country = 'GR' bank = '0110' )
                                        ( bank_country = 'GR' bank = '0140' ) ).
    DATA(other_bank) = valid_cheque( ).
    other_bank-row_number  = 5.
    other_bank-drawee_bank = '0140'.

    " ACT
    DATA(messages) = cut->validate( company_code = company_code
                                    items        = VALUE #( ( valid_cheque( ) ) ( other_bank ) ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial(
      act = messages
      msg = `The same number of the same customer drawn on another bank is another cheque` ).
  ENDMETHOD.

  METHOD given_unknown_customer_then_ms.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-customer = '0000999999'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-customer_unknown ).
  ENDMETHOD.

  METHOD given_unknown_currency_then_ms.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-currency = 'XXX'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-currency_unknown ).
  ENDMETHOD.

  METHOD given_yen_then_msg.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-currency = 'JPY'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-decimals_unsupp ).
  ENDMETHOD.

  METHOD given_unknown_house_bank_then.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-house_bank = 'ALPHA'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-house_bank_unknown ).
  ENDMETHOD.

  METHOD given_unknown_account_then_msg.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-house_bank_account = 'USD01'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-account_unknown ).
  ENDMETHOD.

  METHOD given_unknown_bank_then_warn.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    cheque-drawee_bank = '0999'.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-bank_unknown ).
    cl_abap_unit_assert=>assert_equals( act = messages[ 1 ]-severity
                                        exp = zif_boe_migration=>severity-warning
                                        msg = `A drawee bank outside the bank master data does not stop the cheque` ).
  ENDMETHOD.

  METHOD given_bank_no_country_then_msg.
    " ARRANGE
    DATA(cheque) = valid_cheque( ).
    CLEAR cheque-drawee_bank_country.

    " ACT
    DATA(messages) = findings_about( cheque ).

    " ASSERT
    assert_only_finding( messages = messages
                         number   = finding-bank_country_needed ).
  ENDMETHOD.

  METHOD when_checked_then_own_company.
    " ACT
    findings_about( valid_cheque( ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = master_data->asked_company_code
                                        exp = company_code
                                        msg = `Customers are looked for in the company code of the run` ).
  ENDMETHOD.

  METHOD when_second_file_then_fresh.
    " ARRANGE
    findings_about( valid_cheque( ) ).

    " ACT
    DATA(messages) = findings_about( valid_cheque( ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = messages
                                         msg = `A cheque of an earlier file is no duplicate in the next file` ).
  ENDMETHOD.

ENDCLASS.
