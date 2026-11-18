*"* use this source file for your ABAP unit test classes

CLASS ltc_status_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF transition,
        previous_status TYPE zboe_status,
        new_status      TYPE zboe_status,
      END OF transition.
    TYPES transitions TYPE SORTED TABLE OF transition WITH UNIQUE KEY previous_status new_status.
    TYPES statuses TYPE STANDARD TABLE OF zboe_status WITH EMPTY KEY.

    DATA cut TYPE REF TO zif_boe_status_rules.

    METHODS setup.

    "! The life cycle as the business describes it - written out a second time
    "! on purpose, so that a change of the rules has to be made in two places.
    METHODS expected_transitions
      RETURNING VALUE(result) TYPE transitions.

    METHODS all_statuses
      RETURNING VALUE(result) TYPE statuses.

    METHODS given_life_cycle_then_allowed  FOR TESTING.
    METHODS given_other_change_then_denied FOR TESTING.
    METHODS given_same_status_then_denied  FOR TESTING.
    METHODS given_no_status_then_denied    FOR TESTING.
    METHODS given_end_status_then_final    FOR TESTING.
    METHODS given_open_status_then_open    FOR TESTING.
    METHODS given_final_then_no_way_out    FOR TESTING.
    METHODS given_open_status_then_migrate FOR TESTING.
    METHODS given_endorsed_then_no_migrate FOR TESTING.
    METHODS given_final_then_no_migrate    FOR TESTING.

ENDCLASS.



CLASS ltc_status_rules IMPLEMENTATION.

  METHOD setup.
    cut = NEW zcl_boe_status_rules( ).
  ENDMETHOD.

  METHOD expected_transitions.
    result = VALUE #( ( previous_status = '10' new_status = '20' )
                      ( previous_status = '10' new_status = '30' )
                      ( previous_status = '10' new_status = '40' )
                      ( previous_status = '10' new_status = '50' )
                      ( previous_status = '10' new_status = '70' )
                      ( previous_status = '10' new_status = '90' )
                      ( previous_status = '20' new_status = '10' )
                      ( previous_status = '20' new_status = '50' )
                      ( previous_status = '20' new_status = '60' )
                      ( previous_status = '30' new_status = '10' )
                      ( previous_status = '30' new_status = '50' )
                      ( previous_status = '30' new_status = '60' )
                      ( previous_status = '40' new_status = '10' )
                      ( previous_status = '40' new_status = '50' )
                      ( previous_status = '40' new_status = '60' )
                      ( previous_status = '60' new_status = '30' )
                      ( previous_status = '60' new_status = '70' ) ).
  ENDMETHOD.

  METHOD all_statuses.
    result = VALUE #( ( '10' ) ( '20' ) ( '30' ) ( '40' ) ( '50' ) ( '60' ) ( '70' ) ( '90' ) ).
  ENDMETHOD.

  METHOD given_life_cycle_then_allowed.
    LOOP AT expected_transitions( ) INTO DATA(expected).
      cl_abap_unit_assert=>assert_true(
        act = cut->is_allowed( previous_status = expected-previous_status
                               new_status      = expected-new_status )
        msg = |Change { expected-previous_status } -> { expected-new_status } belongs to the life cycle| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD given_other_change_then_denied.
    DATA(expected) = expected_transitions( ).

    LOOP AT all_statuses( ) INTO DATA(previous_status).
      LOOP AT all_statuses( ) INTO DATA(new_status).
        IF line_exists( expected[ previous_status = previous_status
                                  new_status      = new_status ] ).
          CONTINUE.
        ENDIF.
        cl_abap_unit_assert=>assert_false(
          act = cut->is_allowed( previous_status = previous_status
                                 new_status      = new_status )
          msg = |Change { previous_status } -> { new_status } is not part of the life cycle| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD given_same_status_then_denied.
    cl_abap_unit_assert=>assert_false(
      act = cut->is_allowed( previous_status = zif_boe_status_rules=>status-in_portfolio
                             new_status      = zif_boe_status_rules=>status-in_portfolio )
      msg = `Staying in the same status is not a status change` ).
  ENDMETHOD.

  METHOD given_no_status_then_denied.
    cl_abap_unit_assert=>assert_false(
      act = cut->is_allowed( previous_status = ''
                             new_status      = zif_boe_status_rules=>status-in_portfolio )
      msg = `A bill without a status is not in the register - its first status is no change` ).
  ENDMETHOD.

  METHOD given_end_status_then_final.
    cl_abap_unit_assert=>assert_true( act = cut->is_final( zif_boe_status_rules=>status-collected )
                                      msg = `A collected bill is at the end of its life cycle` ).
    cl_abap_unit_assert=>assert_true( act = cut->is_final( zif_boe_status_rules=>status-returned )
                                      msg = `A returned bill is at the end of its life cycle` ).
    cl_abap_unit_assert=>assert_true( act = cut->is_final( zif_boe_status_rules=>status-cancelled )
                                      msg = `A cancelled bill is at the end of its life cycle` ).
  ENDMETHOD.

  METHOD given_open_status_then_open.
    cl_abap_unit_assert=>assert_false( act = cut->is_final( zif_boe_status_rules=>status-in_portfolio )
                                       msg = `A bill in the portfolio can still change` ).
    cl_abap_unit_assert=>assert_false( act = cut->is_final( zif_boe_status_rules=>status-dishonoured )
                                       msg = `A dishonoured bill can still be returned or presented again` ).
  ENDMETHOD.

  METHOD given_final_then_no_way_out.
    LOOP AT all_statuses( ) INTO DATA(previous_status).
      IF cut->is_final( previous_status ) = abap_false.
        CONTINUE.
      ENDIF.
      LOOP AT all_statuses( ) INTO DATA(new_status).
        cl_abap_unit_assert=>assert_false(
          act = cut->is_allowed( previous_status = previous_status
                                 new_status      = new_status )
          msg = |Final status { previous_status } must not change to { new_status }| ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD given_open_status_then_migrate.
    cl_abap_unit_assert=>assert_true(
      act = cut->is_migration_target( zif_boe_status_rules=>status-in_portfolio )
      msg = `Bills in the portfolio are migrated` ).
    cl_abap_unit_assert=>assert_true(
      act = cut->is_migration_target( zif_boe_status_rules=>status-at_bank_for_collection )
      msg = `Bills at the bank for collection are migrated` ).
    cl_abap_unit_assert=>assert_true(
      act = cut->is_migration_target( zif_boe_status_rules=>status-at_bank_as_collateral )
      msg = `Bills at the bank as collateral are migrated` ).
    cl_abap_unit_assert=>assert_true(
      act = cut->is_migration_target( zif_boe_status_rules=>status-dishonoured )
      msg = `Dishonoured bills are migrated` ).
  ENDMETHOD.

  METHOD given_endorsed_then_no_migrate.
    cl_abap_unit_assert=>assert_false(
      act = cut->is_migration_target( zif_boe_status_rules=>status-endorsed )
      msg = `Endorsed bills are not migrated: the file does not name the supplier` ).
  ENDMETHOD.

  METHOD given_final_then_no_migrate.
    LOOP AT all_statuses( ) INTO DATA(status).
      IF cut->is_final( status ) = abap_false.
        CONTINUE.
      ENDIF.
      cl_abap_unit_assert=>assert_false( act = cut->is_migration_target( status )
                                         msg = |Closed bills (status { status }) are not migrated| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
