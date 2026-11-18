"! <p class="shorttext synchronized" lang="EN">Constants and types of the migration of bills of exchange</p>
"! What the migration workbench and its background processing share: the
"! statuses of a run and of its rows, the columns of the migration file, and
"! a cheque on its way from the file into the register.
INTERFACE zif_boe_migration
  PUBLIC.

  CONSTANTS:
    "! The statuses of a migration run - the fixed values of {@link DOMA:zboe_run_status}.
    BEGIN OF run_status,
      "! The file can be uploaded, checked and corrected.
      open                  TYPE zboe_run_status VALUE '10',
      "! Waiting for the background processing; the run is locked for changes.
      queued                TYPE zboe_run_status VALUE '20',
      "! The background processing is creating the bills.
      in_process            TYPE zboe_run_status VALUE '30',
      "! Every item that was not excluded has become a bill.
      completed             TYPE zboe_run_status VALUE '40',
      "! Some items failed; they can be corrected and processed again.
      completed_with_errors TYPE zboe_run_status VALUE '50',
      "! Given up before any bill was created.
      cancelled             TYPE zboe_run_status VALUE '90',
    END OF run_status.

  CONSTANTS:
    "! The statuses of a row of the migration file - the fixed values of {@link DOMA:zboe_item_status}.
    BEGIN OF item_status,
      "! The row passed every check and can become a bill.
      ready      TYPE zboe_item_status VALUE '10',
      "! A check found an error; the row is corrected in the file and the file is checked again.
      has_errors TYPE zboe_item_status VALUE '20',
      "! The background processing is creating the bill.
      in_process TYPE zboe_item_status VALUE '30',
      "! The bill is in the register.
      migrated   TYPE zboe_item_status VALUE '40',
      "! The bill could not be created.
      failed     TYPE zboe_item_status VALUE '50',
    END OF item_status.

  CONSTANTS:
    "! How serious a message of the file check is.
    BEGIN OF severity,
      "! The row cannot become a bill.
      error   TYPE symsgty VALUE 'E',
      "! The row can become a bill; the message asks for a second look.
      warning TYPE symsgty VALUE 'W',
    END OF severity.

  CONSTANTS:
    "! The columns of sheet Cheques, as row 1 of the template names them.
    BEGIN OF column,
      boe_number          TYPE zboe_column_name VALUE 'BOE_NUMBER',
      customer            TYPE zboe_column_name VALUE 'CUSTOMER',
      amount              TYPE zboe_column_name VALUE 'AMOUNT',
      currency            TYPE zboe_column_name VALUE 'CURRENCY',
      due_date            TYPE zboe_column_name VALUE 'DUE_DATE',
      issue_date          TYPE zboe_column_name VALUE 'ISSUE_DATE',
      target_status       TYPE zboe_column_name VALUE 'TARGET_STATUS',
      drawer_name         TYPE zboe_column_name VALUE 'DRAWER_NAME',
      drawee_bank_country TYPE zboe_column_name VALUE 'DRAWEE_BANK_COUNTRY',
      drawee_bank         TYPE zboe_column_name VALUE 'DRAWEE_BANK',
      drawee_bank_name    TYPE zboe_column_name VALUE 'DRAWEE_BANK_NAME',
      drawee_account      TYPE zboe_column_name VALUE 'DRAWEE_ACCOUNT',
      house_bank          TYPE zboe_column_name VALUE 'HOUSE_BANK',
      house_bank_account  TYPE zboe_column_name VALUE 'HOUSE_BANK_ACCOUNT',
      register_only       TYPE zboe_column_name VALUE 'REGISTER_ONLY',
      legacy_reference    TYPE zboe_column_name VALUE 'LEGACY_REFERENCE',
      note                TYPE zboe_column_name VALUE 'NOTE',
    END OF column.

  CONSTANTS:
    "! The columns without which a row cannot become a bill.
    BEGIN OF mandatory_column,
      boe_number TYPE zboe_column_name VALUE column-boe_number,
      customer   TYPE zboe_column_name VALUE column-customer,
      amount     TYPE zboe_column_name VALUE column-amount,
      currency   TYPE zboe_column_name VALUE column-currency,
      due_date   TYPE zboe_column_name VALUE column-due_date,
    END OF mandatory_column.

  TYPES:
    "! The cells of one row of sheet Cheques as text. The components carry the
    "! names of {@link zif_boe_migration.DATA:column}: a cell is found by the
    "! name of its column.
    BEGIN OF file_cells,
      boe_number          TYPE string,
      customer            TYPE string,
      amount              TYPE string,
      currency            TYPE string,
      due_date            TYPE string,
      issue_date          TYPE string,
      target_status       TYPE string,
      drawer_name         TYPE string,
      drawee_bank_country TYPE string,
      drawee_bank         TYPE string,
      drawee_bank_name    TYPE string,
      drawee_account      TYPE string,
      house_bank          TYPE string,
      house_bank_account  TYPE string,
      register_only       TYPE string,
      legacy_reference    TYPE string,
      note                TYPE string,
    END OF file_cells.

  TYPES:
    "! One row of sheet Cheques before any conversion.
    BEGIN OF file_row,
      "! Row in the sheet, as Excel numbers it.
      row_number TYPE zboe_row_number,
      cells      TYPE file_cells,
    END OF file_row.
  TYPES file_rows TYPE STANDARD TABLE OF file_row WITH EMPTY KEY.

  TYPES:
    "! A cheque of the migration file with converted values. A value that
    "! could not be converted is initial and has a message.
    BEGIN OF item,
      row_number          TYPE zboe_row_number,
      boe_number          TYPE zboe_number,
      customer            TYPE zboe_customer,
      amount              TYPE zboe_amount,
      currency            TYPE zboe_currency,
      due_date            TYPE zboe_due_date,
      issue_date          TYPE zboe_issue_date,
      "! Status the bill gets in the register.
      target_status       TYPE zboe_status,
      drawer_name         TYPE zboe_drawer_name,
      drawee_bank_country TYPE zboe_bank_country,
      drawee_bank         TYPE zboe_bank,
      drawee_bank_name    TYPE zboe_bank_name,
      drawee_account      TYPE zboe_bank_account,
      house_bank          TYPE zboe_house_bank,
      house_bank_account  TYPE zboe_house_bank_account,
      is_register_only    TYPE zboe_register_only,
      legacy_reference    TYPE zboe_legacy_reference,
      note                TYPE zboe_note,
    END OF item.
  TYPES items TYPE STANDARD TABLE OF item WITH EMPTY KEY.

  TYPES:
    "! A finding of the file check about one row.
    BEGIN OF message,
      row_number TYPE zboe_row_number,
      "! Column the finding is about; initial when it concerns the row as a whole.
      column     TYPE zboe_column_name,
      severity   TYPE symsgty,
      id         TYPE symsgid,
      number     TYPE symsgno,
      variable_1 TYPE symsgv,
      variable_2 TYPE symsgv,
      variable_3 TYPE symsgv,
      variable_4 TYPE symsgv,
      "! The message in the language of the user who checked the file.
      text       TYPE zboe_message_text,
    END OF message.
  TYPES messages TYPE STANDARD TABLE OF message WITH EMPTY KEY.

  TYPES:
    "! A cheque of the migration file with the outcome of the check.
    BEGIN OF checked_item,
      item     TYPE item,
      status   TYPE zboe_item_status,
      messages TYPE messages,
    END OF checked_item.
  TYPES checked_items TYPE STANDARD TABLE OF checked_item WITH EMPTY KEY.

  TYPES:
    "! Outcome of the check of a migration file.
    BEGIN OF check_result,
      "! The cheques in the order of the file.
      items       TYPE checked_items,
      item_count  TYPE zboe_item_count,
      "! Cheques with at least one error.
      error_count TYPE zboe_error_count,
    END OF check_result.

ENDINTERFACE.
