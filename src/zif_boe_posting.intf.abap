"! <p class="shorttext synchronized" lang="EN">Posting of bills of exchange to financial accounting</p>
"! The one contract between the core and the edition: everything that differs
"! between S/4HANA Cloud Public Edition and Private Edition / on-premise when a
"! bill of exchange reaches financial accounting sits behind this interface.
"! The core obtains the implementation from {@link zif_boe_posting_provider}
"! and never names an implementing class.
"! <br>
"! Transaction handling: {@link zif_boe_posting.METH:post} and
"! {@link zif_boe_posting.METH:reverse} return with the accounting document
"! already committed. They are therefore called only where a commit is allowed
"! and the caller has no uncommitted changes - from the migration job, never
"! from a RAP behavior pool. {@link zif_boe_posting.METH:check} and
"! {@link zif_boe_posting.METH:find_document} only read and are safe anywhere.
INTERFACE zif_boe_posting
  PUBLIC.

  TYPES:
    "! The bill of exchange as the register knows it. No accounts: which
    "! accounts and indicators a status maps to is configuration of the adapter.
    BEGIN OF bill,
      direction           TYPE zboe_direction,
      boe_number          TYPE zboe_number,
      company_code        TYPE zboe_company_code,
      customer            TYPE zboe_customer,
      drawer_name         TYPE zboe_drawer_name,
      drawee_bank_country TYPE zboe_bank_country,
      drawee_bank         TYPE zboe_bank,
      drawee_bank_name    TYPE zboe_bank_name,
      drawee_account      TYPE zboe_bank_account,
      issue_date          TYPE d,
      due_date            TYPE d,
      amount              TYPE zboe_amount,
      currency            TYPE zboe_currency,
      house_bank          TYPE zboe_house_bank,
      house_bank_account  TYPE zboe_house_bank_account,
    END OF bill.

  TYPES:
    "! One business event of a bill that has an effect in accounting.
    BEGIN OF request,
      "! Identifies the event. The same id is never posted twice: the adapter
      "! stores it with the document and finds the document by it again.
      posting_id      TYPE sysuuid_x16,
      bill            TYPE bill,
      "! Initial when the bill enters the register (receipt, migration).
      previous_status TYPE zboe_status,
      new_status      TYPE zboe_status,
      posting_date    TYPE d,
      document_date   TYPE d,
      "! Initial load from a legacy system: the offsetting entry goes to the
      "! migration account of the adapter and no open invoice is cleared.
      is_migration    TYPE abap_bool,
    END OF request.

  TYPES:
    "! Key of an accounting document.
    BEGIN OF document,
      company_code        TYPE zboe_company_code,
      accounting_document TYPE zboe_document,
      fiscal_year         TYPE zboe_fiscal_year,
    END OF document.

  TYPES:
    "! Reversal of a document that this interface has posted.
    BEGIN OF reversal,
      "! Identifies the reversal itself, with the same promise as the id of a request.
      posting_id   TYPE sysuuid_x16,
      document     TYPE document,
      posting_date TYPE d,
    END OF reversal.

  TYPES:
    "! A message of the adapter or of financial accounting, language independent.
    BEGIN OF message,
      id         TYPE symsgid,
      number     TYPE symsgno,
      severity   TYPE symsgty,
      variable_1 TYPE symsgv,
      variable_2 TYPE symsgv,
      variable_3 TYPE symsgv,
      variable_4 TYPE symsgv,
    END OF message.
  TYPES messages TYPE STANDARD TABLE OF message WITH EMPTY KEY.

  "! Tells what would stop the request from being posted, as far as the
  "! edition can tell without posting: missing configuration of the adapter,
  "! a status it does not support, master data that accounting rejects.
  "! Writes nothing and never commits.
  "!
  "! @parameter request | The event as it would be passed to {@link zif_boe_posting.METH:post}
  "! @parameter result  | Findings; no entry of severity E, A or X means the request can be posted
  METHODS check
    IMPORTING request       TYPE request
    RETURNING VALUE(result) TYPE messages.

  "! Posts the accounting document of the event and commits it.
  "! A request whose posting id already has a document is not posted again;
  "! callers that retry after an exception ask
  "! {@link zif_boe_posting.METH:find_document} first.
  "!
  "! @parameter request         | The event to post
  "! @parameter result          | The document that was created
  "! @raising   zcx_boe_posting | Accounting rejected the document, or the outcome is unknown;
  "!                              the exception carries the messages of accounting
  METHODS post
    IMPORTING request       TYPE request
    RETURNING VALUE(result) TYPE document
    RAISING   zcx_boe_posting.

  "! Reverses a document posted through this interface and commits the reversal.
  "!
  "! @parameter reversal        | The document to reverse and the id of the reversal
  "! @parameter result          | The reversal document
  "! @raising   zcx_boe_posting | Accounting rejected the reversal, or the outcome is unknown
  METHODS reverse
    IMPORTING reversal      TYPE reversal
    RETURNING VALUE(result) TYPE document
    RAISING   zcx_boe_posting.

  "! Finds the document that was posted for an event, so that an event whose
  "! outcome is unknown is not posted a second time.
  "!
  "! @parameter posting_id      | Id of the event, as passed in the request or the reversal
  "! @parameter result          | The document; initial when the event has not been posted
  "! @raising   zcx_boe_posting | Accounting could not be read
  METHODS find_document
    IMPORTING posting_id    TYPE sysuuid_x16
    RETURNING VALUE(result) TYPE document
    RAISING   zcx_boe_posting.

ENDINTERFACE.
