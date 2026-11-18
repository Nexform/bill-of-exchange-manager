"! <p class="shorttext synchronized" lang="EN">A bill of exchange could not be posted</p>
"! Raised by the implementations of {@link zif_boe_posting}. The text is the
"! leading message, set with the MESSAGE addition of RAISE EXCEPTION; every
"! message that accounting returned travels in
"! {@link zcx_boe_posting.DATA:messages}.
"! <br>
"! After this exception the outcome counts as unknown: the document may exist.
"! A caller that retries asks {@link zif_boe_posting.METH:find_document} first.
CLASS zcx_boe_posting DEFINITION
  PUBLIC
  INHERITING FROM zcx_boe_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Everything the adapter or accounting reported, in the order it was reported.
    DATA messages TYPE zif_boe_posting=>messages READ-ONLY.

    "! @parameter textid   | Fixed text id; initial when the message is set at raise time
    "! @parameter previous | The exception that caused this one
    "! @parameter messages | Messages of the adapter or of accounting
    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL
                messages TYPE zif_boe_posting=>messages OPTIONAL.

ENDCLASS.



CLASS zcx_boe_posting IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid   = textid
                        previous = previous ).
    me->messages = messages.
  ENDMETHOD.

ENDCLASS.
