"! <p class="shorttext synchronized" lang="EN">Master data that the cheques of a migration refer to</p>
"! Reads the released views of financial accounting. The access controls of
"! those views apply: master data that the user may not display counts as
"! not existing. Nothing is buffered - a check of a file calls each method once.
CLASS zcl_boe_master_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_master_data.

ENDCLASS.



CLASS zcl_boe_master_data IMPLEMENTATION.

  METHOD zif_boe_master_data~existing_company_codes.
    IF company_codes IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM i_companycodestdvh AS company
      INNER JOIN @company_codes AS wanted
        ON wanted~company_code = company~companycode
      FIELDS company~companycode AS company_code
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD zif_boe_master_data~customers_in_company.
    IF customers IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM i_customercompany AS company
      INNER JOIN @customers AS wanted
        ON wanted~customer = company~customer
      FIELDS company~customer
      WHERE company~companycode = @company_code
      INTO TABLE @result.
  ENDMETHOD.

  METHOD zif_boe_master_data~currencies.
    SELECT FROM i_currency
      FIELDS currency,
             decimals
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD zif_boe_master_data~existing_banks.
    IF banks IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM i_bank_2 AS bank
      INNER JOIN @banks AS wanted
        ON  wanted~bank_country = bank~bankcountry
        AND wanted~bank         = bank~bankinternalid
      FIELDS bank~bankcountry    AS bank_country,
             bank~bankinternalid AS bank
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD zif_boe_master_data~house_bank_accounts.
    SELECT FROM i_housebankaccountlinkage
      FIELDS housebank        AS house_bank,
             housebankaccount AS house_bank_account
      WHERE companycode = @company_code
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

ENDCLASS.
