"! <p class="shorttext synchronized" lang="EN">The migration file cannot be read</p>
"! Raised by {@link zif_boe_xlsx_reader} when the uploaded file as a whole is
"! unusable, so that no row of it can be checked. The text says what is wrong
"! with the file and is set with the MESSAGE addition of RAISE EXCEPTION.
CLASS zcx_boe_file DEFINITION
  PUBLIC
  INHERITING FROM zcx_boe_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter textid   | Fixed text id; initial when the message is set at raise time
    "! @parameter previous | The exception that caused this one
    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL.

ENDCLASS.



CLASS zcx_boe_file IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid   = textid
                        previous = previous ).
  ENDMETHOD.

ENDCLASS.
