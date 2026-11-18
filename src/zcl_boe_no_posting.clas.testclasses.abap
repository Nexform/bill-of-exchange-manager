*"* use this source file for your ABAP unit test classes

CLASS ltc_no_posting DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS no_adapter_message TYPE symsgno VALUE '020'.
    CONSTANTS any_posting_id TYPE sysuuid_x16 VALUE '0123456789ABCDEF0123456789ABCDEF'.

    DATA cut TYPE REF TO zif_boe_posting.

    METHODS setup.

    METHODS when_check_then_one_error  FOR TESTING RAISING cx_static_check.
    METHODS when_post_then_raises      FOR TESTING RAISING cx_static_check.
    METHODS when_reverse_then_raises   FOR TESTING RAISING cx_static_check.
    METHODS when_find_then_no_document FOR TESTING RAISING cx_static_check.

ENDCLASS.



CLASS ltc_no_posting IMPLEMENTATION.

  METHOD setup.
    cut = NEW zcl_boe_no_posting( ).
  ENDMETHOD.

  METHOD when_check_then_one_error.
    " ACT
    DATA(findings) = cut->check( VALUE #( ) ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = lines( findings )
                                        exp = 1
                                        msg = `The missing adapter is reported once` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-id
                                        exp = 'ZBOE'
                                        msg = `The finding comes from the message class of the application` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-number
                                        exp = no_adapter_message
                                        msg = `The finding must say that no adapter is installed` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-severity
                                        exp = 'E'
                                        msg = `A bill that needs a document cannot be created - that is an error` ).
  ENDMETHOD.

  METHOD when_post_then_raises.
    " ACT / ASSERT
    TRY.
        cut->post( VALUE #( ) ).
        cl_abap_unit_assert=>fail( msg = `Posting without an adapter must raise zcx_boe_posting` ).
      CATCH zcx_boe_posting INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = no_adapter_message
                                            msg = `The exception text must say that no adapter is installed` ).
        cl_abap_unit_assert=>assert_equals( act = lines( error->messages )
                                            exp = 1
                                            msg = `The exception carries the finding for the item messages` ).
    ENDTRY.
  ENDMETHOD.

  METHOD when_reverse_then_raises.
    " ACT / ASSERT
    TRY.
        cut->reverse( VALUE #( ) ).
        cl_abap_unit_assert=>fail( msg = `Reversing without an adapter must raise zcx_boe_posting` ).
      CATCH zcx_boe_posting INTO DATA(error).
        cl_abap_unit_assert=>assert_equals( act = error->if_t100_message~t100key-msgno
                                            exp = no_adapter_message
                                            msg = `The exception text must say that no adapter is installed` ).
    ENDTRY.
  ENDMETHOD.

  METHOD when_find_then_no_document.
    " ACT
    DATA(document) = cut->find_document( any_posting_id ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = document
                                         msg = `Without an adapter no event has a document` ).
  ENDMETHOD.

ENDCLASS.
