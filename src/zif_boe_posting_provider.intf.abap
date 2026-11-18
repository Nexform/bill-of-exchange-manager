"! <p class="shorttext synchronized" lang="EN">Finds the posting adapter of the edition</p>
"! The core never names the class that posts to financial accounting: an
"! edition adapter registers itself by name, and the core asks this interface
"! for the object behind the name. That keeps the core free of anything that
"! exists only in one edition.
INTERFACE zif_boe_posting_provider
  PUBLIC.

  "! Hands out the posting adapter of this system.
  "! Without a registered adapter the result is an adapter that posts nothing
  "! and says so - bills can then only be kept in the register.
  "!
  "! @parameter result          | The registered adapter, or the adapter of a system without one
  "! @raising   zcx_boe_adapter | The registered class no longer exists or is no posting adapter
  METHODS posting
    RETURNING VALUE(result) TYPE REF TO zif_boe_posting
    RAISING   zcx_boe_adapter.

  "! Makes a class the posting adapter of this system, replacing the one
  "! registered before. Called once by the set-up of an edition adapter.
  "! The entry is written but not committed - that is left to the caller.
  "!
  "! @parameter class_name      | Global class that implements {@link zif_boe_posting}
  "!                              and can be instantiated without parameters
  "! @raising   zcx_boe_adapter | The class does not exist, is no posting adapter or could not be stored;
  "!                              the registry is unchanged
  METHODS register
    IMPORTING class_name TYPE zboe_class_name
    RAISING   zcx_boe_adapter.

ENDINTERFACE.
