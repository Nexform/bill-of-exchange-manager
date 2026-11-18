*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">CDS and draft table doubles for the tests of the run</p>
"! READ ENTITIES is served through the CDS entity, so the entity is doubled
"! with its base dependencies, which doubles ZTBOE_RUN as well. The draft table
"! is declared in the behavior definition and needs a double of its own.
CLASS lth_run_doubles DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    "! Creates both doubles once; further calls do nothing.
    CLASS-METHODS create.
    "! Destroys both doubles.
    CLASS-METHODS destroy.
    "! Empties both doubles - called in every setup.
    CLASS-METHODS clear.

  PRIVATE SECTION.
    CLASS-DATA cds_environment   TYPE REF TO if_cds_test_environment.
    CLASS-DATA draft_environment TYPE REF TO if_osql_test_environment.
ENDCLASS.


CLASS lth_run_doubles IMPLEMENTATION.
  METHOD create.
    IF cds_environment IS BOUND.
      RETURN.
    ENDIF.

    cds_environment = cl_cds_test_environment=>create_for_multiple_cds(
                          i_for_entities = VALUE #( ( i_for_entity               = 'ZR_BOEMIGRATIONRUN'
                                                      i_select_base_dependencies = abap_true ) ) ).

    draft_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZTBOE_RUN_D' ) ) ).
  ENDMETHOD.

  METHOD destroy.
    IF cds_environment IS NOT BOUND.
      RETURN.
    ENDIF.

    cds_environment->destroy( ).
    draft_environment->destroy( ).
    CLEAR cds_environment.
    CLEAR draft_environment.
  ENDMETHOD.

  METHOD clear.
    cds_environment->clear_doubles( ).
    draft_environment->clear_doubles( ).
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">The run through EML: initial status and header checks</p>
"! Drives the business object the way a consumer does, so that the wiring of
"! the behavior definition is tested together with the handler.
"! @testing BDEF:ZR_BoEMigrationRun
CLASS ltc_run DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED   LATE zr_boemigrationrun.
    TYPES reported_late TYPE RESPONSE FOR REPORTED LATE zr_boemigrationrun.

    "! Message numbers of ZBOE that the header checks report.
    CONSTANTS:
      BEGIN OF message,
        company_code_missing TYPE symsgno VALUE '030',
        posting_date_missing TYPE symsgno VALUE '031',
      END OF message.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    "! Creates a run and takes it through the save sequence.
    "! Every parameter defaults to a valid value, so a test names only what it
    "! wants to be wrong.
    "!
    "! @parameter company_code | Company code of the run
    "! @parameter posting_date | Posting date of the run
    "! @parameter failed       | Runs the save sequence rejected
    "! @parameter reported     | Messages of the save sequence
    METHODS create_and_save
      IMPORTING company_code TYPE zboe_company_code DEFAULT 'GR01'
                posting_date TYPE zboe_posting_date DEFAULT '20261231'
      EXPORTING failed       TYPE failed_late
                reported     TYPE reported_late.

    "! Asserts that the save sequence reported a message of ZBOE.
    "!
    "! @parameter reported | Messages of the save sequence
    "! @parameter expected | Message number that has to be among them
    METHODS assert_message
      IMPORTING reported TYPE reported_late
                expected TYPE symsgno.

    METHODS given_valid_run_then_saved     FOR TESTING.
    METHODS given_no_company_then_rejected FOR TESTING.
    METHODS given_no_date_then_rejected    FOR TESTING.
    METHODS when_created_then_status_open  FOR TESTING.

ENDCLASS.


CLASS ltc_run IMPLEMENTATION.

  METHOD class_setup.
    lth_run_doubles=>create( ).
  ENDMETHOD.

  METHOD class_teardown.
    lth_run_doubles=>destroy( ).
  ENDMETHOD.

  METHOD setup.
    lth_run_doubles=>clear( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD create_and_save.
    MODIFY ENTITIES OF zr_boemigrationrun
           ENTITY run
           CREATE FIELDS ( description companycode postingdate )
           WITH VALUE #( ( %cid        = 'RUN1'
                           description = 'Cutover'
                           companycode = company_code
                           postingdate = posting_date ) ).

    COMMIT ENTITIES RESPONSE OF zr_boemigrationrun
           FAILED   DATA(commit_failed)
           REPORTED DATA(commit_reported).

    failed   = commit_failed.
    reported = commit_reported.
  ENDMETHOD.

  METHOD assert_message.
    DATA(found) = abap_false.

    LOOP AT reported-run INTO DATA(entry).
      " entries that only clear a state area carry no message object
      IF entry-%msg IS BOUND AND entry-%msg->if_t100_message~t100key-msgno = expected.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true( act = found
                                      msg = |Message { expected } of ZBOE was not reported on save| ).
  ENDMETHOD.

  METHOD given_valid_run_then_saved.
    " ACT
    create_and_save( IMPORTING failed = DATA(failed) ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = failed-run
                                         msg = `A run with company code and posting date must be saved` ).
  ENDMETHOD.

  METHOD given_no_company_then_rejected.
    " ACT
    create_and_save( EXPORTING company_code = VALUE #( )
                     IMPORTING failed       = DATA(failed)
                               reported     = DATA(reported) ).

    " ASSERT
    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = `A run without a company code must be rejected` ).
    assert_message( reported = reported
                    expected = message-company_code_missing ).
  ENDMETHOD.

  METHOD given_no_date_then_rejected.
    " ACT
    create_and_save( EXPORTING posting_date = VALUE #( )
                     IMPORTING failed       = DATA(failed)
                               reported     = DATA(reported) ).

    " ASSERT
    cl_abap_unit_assert=>assert_not_initial( act = failed-run
                                             msg = `A run without a posting date must be rejected` ).
    assert_message( reported = reported
                    expected = message-posting_date_missing ).
  ENDMETHOD.

  METHOD when_created_then_status_open.
    " ACT
    MODIFY ENTITIES OF zr_boemigrationrun
           ENTITY run
           CREATE FIELDS ( description companycode postingdate )
           WITH VALUE #( ( %cid        = 'RUN1'
                           description = 'Cutover'
                           companycode = 'GR01'
                           postingdate = '20261231' ) )
           MAPPED DATA(mapped).

    READ ENTITIES OF zr_boemigrationrun
         ENTITY run
         FIELDS ( status )
         WITH VALUE #( ( %tky = mapped-run[ 1 ]-%tky ) )
         RESULT DATA(runs).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = runs[ 1 ]-status
                                        exp = zif_boe_migration=>run_status-open
                                        msg = `A new run starts in status open` ).
  ENDMETHOD.

ENDCLASS.
