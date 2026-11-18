"! <p class="shorttext synchronized" lang="EN">Master data that the cheques of a migration refer to</p>
"! The one place where the core reads master data of financial accounting.
"! Every method answers for many keys at once, so that checking a file costs
"! a handful of database accesses however many cheques it has.
INTERFACE zif_boe_master_data
  PUBLIC.

  TYPES:
    BEGIN OF company_code_key,
      company_code TYPE zboe_company_code,
    END OF company_code_key.
  TYPES company_code_keys TYPE SORTED TABLE OF company_code_key WITH UNIQUE KEY company_code.

  TYPES:
    BEGIN OF customer_key,
      customer TYPE zboe_customer,
    END OF customer_key.
  TYPES customer_keys TYPE SORTED TABLE OF customer_key WITH UNIQUE KEY customer.

  TYPES:
    BEGIN OF currency_info,
      currency TYPE zboe_currency,
      "! Decimal places of amounts in this currency.
      decimals TYPE i,
    END OF currency_info.
  TYPES currency_infos TYPE HASHED TABLE OF currency_info WITH UNIQUE KEY currency.

  TYPES:
    BEGIN OF bank_key,
      bank_country TYPE zboe_bank_country,
      bank         TYPE zboe_bank,
    END OF bank_key.
  TYPES bank_keys TYPE SORTED TABLE OF bank_key WITH UNIQUE KEY bank_country bank.

  TYPES:
    BEGIN OF account_key,
      house_bank         TYPE zboe_house_bank,
      house_bank_account TYPE zboe_house_bank_account,
    END OF account_key.
  TYPES account_keys TYPE SORTED TABLE OF account_key WITH UNIQUE KEY house_bank house_bank_account.

  "! Picks the company codes that exist.
  "!
  "! @parameter company_codes | Company codes to look for
  "! @parameter result        | Those of them that exist
  METHODS existing_company_codes
    IMPORTING company_codes TYPE company_code_keys
    RETURNING VALUE(result) TYPE company_code_keys.

  "! Picks the customers that exist in a company code.
  "!
  "! @parameter company_code | Company code the customers have to be created in
  "! @parameter customers    | Customers to look for
  "! @parameter result       | Those of them that exist in the company code
  METHODS customers_in_company
    IMPORTING company_code  TYPE zboe_company_code
              customers     TYPE customer_keys
    RETURNING VALUE(result) TYPE customer_keys.

  "! Returns every currency of the system with its decimal places.
  "!
  "! @parameter result | The currencies
  METHODS currencies
    RETURNING VALUE(result) TYPE currency_infos.

  "! Picks the banks that exist in the bank master data.
  "!
  "! @parameter banks  | Banks to look for
  "! @parameter result | Those of them that exist
  METHODS existing_banks
    IMPORTING banks         TYPE bank_keys
    RETURNING VALUE(result) TYPE bank_keys.

  "! Returns the accounts at the house banks of a company code.
  "!
  "! @parameter company_code | Company code of the house banks
  "! @parameter result       | Every account, with its house bank
  METHODS house_bank_accounts
    IMPORTING company_code  TYPE zboe_company_code
    RETURNING VALUE(result) TYPE account_keys.

ENDINTERFACE.
