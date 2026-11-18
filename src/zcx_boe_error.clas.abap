"! <p class="shorttext synchronized" lang="EN">Bill of Exchange Manager: root of all exceptions</p>
"! Every exception of the application inherits from this class, so that a
"! caller can catch the application as a whole. Texts come from message class
"! ZBOE, either through a fixed text id of the subclass or through the
"! MESSAGE addition of RAISE EXCEPTION.
CLASS zcx_boe_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    "! @parameter textid   | Fixed text id of the subclass; initial when the message is set at raise time
    "! @parameter previous | The exception that caused this one
    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL.

ENDCLASS.



CLASS zcx_boe_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
