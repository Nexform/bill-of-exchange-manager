"! <p class="shorttext synchronized" lang="EN">The posting adapter of the edition cannot be used</p>
"! Raised by {@link zif_boe_posting_provider} when the class named in the
"! adapter registry cannot serve as posting adapter. The text says why and is
"! set with the MESSAGE addition of RAISE EXCEPTION.
CLASS zcx_boe_adapter DEFINITION
  PUBLIC
  INHERITING FROM zcx_boe_error
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! The adapter class the registry names.
    DATA class_name TYPE zboe_class_name READ-ONLY.

    "! @parameter textid     | Fixed text id; initial when the message is set at raise time
    "! @parameter previous   | The exception that caused this one
    "! @parameter class_name | The adapter class the registry names
    METHODS constructor
      IMPORTING textid     LIKE if_t100_message=>t100key OPTIONAL
                previous   LIKE previous OPTIONAL
                class_name TYPE zboe_class_name OPTIONAL.

ENDCLASS.



CLASS zcx_boe_adapter IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( textid   = textid
                        previous = previous ).
    me->class_name = class_name.
  ENDMETHOD.

ENDCLASS.
