*"* use this source file for your ABAP unit test classes

CLASS ltc_posting_provider DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES registrations TYPE STANDARD TABLE OF ztboe_adapter WITH EMPTY KEY.

    "! A core class that exists, can be created and is no posting adapter.
    CONSTANTS no_adapter_class TYPE zboe_class_name VALUE 'ZCL_BOE_STATUS_RULES'.
    CONSTANTS missing_class TYPE zboe_class_name VALUE 'ZCL_BOE_NOT_IN_THIS_SYSTEM'.

    "! Message numbers of ZBOE that tell the failures of the provider apart.
    CONSTANTS:
      BEGIN OF failure,
        class_not_found TYPE symsgno VALUE '010',
        wrong_type      TYPE symsgno VALUE '011',
      END OF failure.

    CLASS-DATA sql_environment TYPE REF TO if_osql_test_environment.

    DATA cut TYPE REF TO zif_boe_posting_provider.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    "! Puts an entry into the registry without going through the class under test.
    METHODS given_registry_names
      IMPORTING class_name TYPE zboe_class_name.

    METHODS registered_classes
      RETURNING VALUE(result) TYPE registrations.

    METHODS given_no_entry_then_no_posting FOR TESTING RAISING cx_static_check.
    METHODS given_entry_then_adapter       FOR TESTING RAISING cx_static_check.
    METHODS given_missing_class_then_error FOR TESTING RAISING cx_static_check.
    METHODS given_other_class_then_error   FOR TESTING RAISING cx_static_check.
    METHODS when_register_then_stored      FOR TESTING RAISING cx_static_check.
    METHODS when_register_twice_then_one   FOR TESTING RAISING cx_static_check.
    METHODS when_register_missing_then_err FOR TESTING RAISING cx_static_check.
    METHODS when_register_other_then_error FOR TESTING RAISING cx_static_check.

ENDCLASS.



CLASS ltc_posting_provider IMPLEMENTATION.

  METHOD class_setup.
    sql_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZTBOE_ADAPTER' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    sql_environment->clear_doubles( ).
    cut = NEW zcl_boe_posting_provider( ).
  ENDMETHOD.

  METHOD given_registry_names.
    DATA registry TYPE registrations.

    registry = VALUE #( ( adapter_role = 'POSTING' class_name = class_name ) ).
    sql_environment->insert_test_data( registry ).
  ENDMETHOD.

  METHOD registered_classes.
    SELECT FROM ztboe_adapter
      FIELDS adapter_role, class_name
      ORDER BY adapter_role
      INTO CORRESPONDING FIELDS OF TABLE @result.
  ENDMETHOD.

  METHOD given_no_entry_then_no_posting.
    " ACT
    DATA(posting) = cut->posting( ).

    " ASSERT
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( posting IS INSTANCE OF zcl_boe_no_posting )
      msg = `Without a registered adapter the system keeps bills in the register only` ).
  ENDMETHOD.

  METHOD given_entry_then_adapter.
    " ARRANGE
    given_registry_names( 'ZCL_BOE_NO_POSTING' ).

    " ACT
    DATA(posting) = cut->posting( ).

    " ASSERT
    cl_abap_unit_assert=>assert_bound( act = posting
                                       msg = `The class named in the registry must be created` ).
  ENDMETHOD.

  METHOD given_missing_class_then_error.
    " ARRANGE
    given_registry_names( missing_class ).

    " ACT / ASSERT
    TRY.
        cut->posting( ).
        cl_abap_unit_assert=>fail( msg = `A registered class that does not exist must raise zcx_boe_adapter` ).
      CATCH zcx_boe_adapter INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = failure-class_not_found
                                            msg = `Wrong failure kind - expected class_not_found` ).
        cl_abap_unit_assert=>assert_equals( act = error->class_name
                                            exp = missing_class
                                            msg = `The exception must name the class of the registry` ).
    ENDTRY.
  ENDMETHOD.

  METHOD given_other_class_then_error.
    " ARRANGE
    given_registry_names( no_adapter_class ).

    " ACT / ASSERT
    TRY.
        cut->posting( ).
        cl_abap_unit_assert=>fail( msg = `A registered class without zif_boe_posting must raise zcx_boe_adapter` ).
      CATCH zcx_boe_adapter INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = failure-wrong_type
                                            msg = `Wrong failure kind - expected wrong_type` ).
    ENDTRY.
  ENDMETHOD.

  METHOD when_register_then_stored.
    " ACT
    cut->register( 'zcl_boe_no_posting' ).

    " ASSERT
    DATA(registered) = registered_classes( ).
    cl_abap_unit_assert=>assert_equals( act = lines( registered )
                                        exp = 1
                                        msg = `Registering an adapter writes one registry entry` ).
    cl_abap_unit_assert=>assert_equals( act = registered[ 1 ]-class_name
                                        exp = 'ZCL_BOE_NO_POSTING'
                                        msg = `The class name is stored in upper case, as class names are` ).
  ENDMETHOD.

  METHOD when_register_twice_then_one.
    " ARRANGE
    given_registry_names( missing_class ).

    " ACT
    cut->register( 'ZCL_BOE_NO_POSTING' ).

    " ASSERT
    DATA(registered) = registered_classes( ).
    cl_abap_unit_assert=>assert_equals( act = lines( registered )
                                        exp = 1
                                        msg = `A system has one posting adapter - the new one replaces the old` ).
    cl_abap_unit_assert=>assert_equals( act = registered[ 1 ]-class_name
                                        exp = 'ZCL_BOE_NO_POSTING'
                                        msg = `The registry must name the adapter registered last` ).
  ENDMETHOD.

  METHOD when_register_missing_then_err.
    " ACT / ASSERT
    TRY.
        cut->register( missing_class ).
        cl_abap_unit_assert=>fail( msg = `Registering a class that does not exist must raise zcx_boe_adapter` ).
      CATCH zcx_boe_adapter INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = failure-class_not_found
                                            msg = `Wrong failure kind - expected class_not_found` ).
    ENDTRY.

    cl_abap_unit_assert=>assert_initial( act = registered_classes( )
                                         msg = `A rejected class must not reach the registry` ).
  ENDMETHOD.

  METHOD when_register_other_then_error.
    " ACT / ASSERT
    TRY.
        cut->register( no_adapter_class ).
        cl_abap_unit_assert=>fail( msg = `Registering a class without zif_boe_posting must raise zcx_boe_adapter` ).
      CATCH zcx_boe_adapter INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = failure-wrong_type
                                            msg = `Wrong failure kind - expected wrong_type` ).
    ENDTRY.

    cl_abap_unit_assert=>assert_initial( act = registered_classes( )
                                         msg = `A rejected class must not reach the registry` ).
  ENDMETHOD.

ENDCLASS.
