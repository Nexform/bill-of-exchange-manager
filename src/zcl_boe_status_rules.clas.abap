"! <p class="shorttext synchronized" lang="EN">Status rules of a bill of exchange</p>
"! The life cycle of a received bill as one table of allowed status changes.
"! Free of RAP and of persistence, so that every rule is tested directly.
CLASS zcl_boe_status_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_status_rules.

    "! Builds the table of allowed status changes.
    METHODS constructor.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF transition,
        previous_status TYPE zboe_status,
        new_status      TYPE zboe_status,
      END OF transition.
    TYPES transitions TYPE HASHED TABLE OF transition WITH UNIQUE KEY previous_status new_status.
    TYPES statuses TYPE HASHED TABLE OF zboe_status WITH UNIQUE KEY table_line.

    DATA allowed_transitions TYPE transitions.
    DATA final_statuses TYPE statuses.
    DATA migration_targets TYPE statuses.

ENDCLASS.



CLASS zcl_boe_status_rules IMPLEMENTATION.

  METHOD constructor.
    DATA(status) = zif_boe_status_rules=>status.

    allowed_transitions = VALUE #(
      ( previous_status = status-in_portfolio           new_status = status-endorsed )
      ( previous_status = status-in_portfolio           new_status = status-at_bank_for_collection )
      ( previous_status = status-in_portfolio           new_status = status-at_bank_as_collateral )
      ( previous_status = status-in_portfolio           new_status = status-collected )
      ( previous_status = status-in_portfolio           new_status = status-returned )
      ( previous_status = status-in_portfolio           new_status = status-cancelled )
      ( previous_status = status-endorsed               new_status = status-in_portfolio )
      ( previous_status = status-endorsed               new_status = status-collected )
      ( previous_status = status-endorsed               new_status = status-dishonoured )
      ( previous_status = status-at_bank_for_collection new_status = status-in_portfolio )
      ( previous_status = status-at_bank_for_collection new_status = status-collected )
      ( previous_status = status-at_bank_for_collection new_status = status-dishonoured )
      ( previous_status = status-at_bank_as_collateral  new_status = status-in_portfolio )
      ( previous_status = status-at_bank_as_collateral  new_status = status-collected )
      ( previous_status = status-at_bank_as_collateral  new_status = status-dishonoured )
      ( previous_status = status-dishonoured            new_status = status-at_bank_for_collection )
      ( previous_status = status-dishonoured            new_status = status-returned ) ).

    final_statuses = VALUE #( ( status-collected )
                              ( status-returned )
                              ( status-cancelled ) ).

    " an endorsed bill needs the supplier it went to, which the migration file does not carry yet
    migration_targets = VALUE #( ( status-in_portfolio )
                                 ( status-at_bank_for_collection )
                                 ( status-at_bank_as_collateral )
                                 ( status-dishonoured ) ).
  ENDMETHOD.

  METHOD zif_boe_status_rules~is_allowed.
    result = xsdbool( line_exists( allowed_transitions[ previous_status = previous_status
                                                        new_status      = new_status ] ) ).
  ENDMETHOD.

  METHOD zif_boe_status_rules~is_final.
    result = xsdbool( line_exists( final_statuses[ table_line = status ] ) ).
  ENDMETHOD.

  METHOD zif_boe_status_rules~is_migration_target.
    result = xsdbool( line_exists( migration_targets[ table_line = status ] ) ).
  ENDMETHOD.

ENDCLASS.
