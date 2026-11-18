*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Authorization double: one company code is allowed</p>
"! Stub of {@link zif_boe_authorization}. A test changes the public attributes
"! to describe the user it needs.
CLASS ltd_authorization DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_boe_authorization.

    "! Answer to the question whether the user may create runs at all.
    DATA create_allowed TYPE abap_bool VALUE abap_true.
    "! The one company code the user may post in.
    DATA company_code   TYPE zboe_company_code VALUE 'GR01'.
ENDCLASS.


CLASS ltd_authorization IMPLEMENTATION.
  METHOD zif_boe_authorization~is_create_allowed.
    result = create_allowed.
  ENDMETHOD.

  METHOD zif_boe_authorization~is_change_allowed.
    result = xsdbool( company_code = me->company_code ).
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">CDS and draft table doubles for the tests of the run</p>
"! READ ENTITIES is served through the CDS entity, so the entity is doubled
"! with its base dependencies, which doubles ZTBOE_RUN as well. The draft table
"! is declared in the behavior definition and needs a double of its own.
CLASS lth_run_doubles DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    TYPES runs TYPE STANDARD TABLE OF ztboe_run WITH EMPTY KEY.

    "! Key of the run that {@link lth_run_doubles.METH:run} builds.
    CONSTANTS run_uuid TYPE sysuuid_x16 VALUE '11111111111111111111111111111111'.

    "! Creates both doubles once; further calls do nothing.
    CLASS-METHODS create.
    "! Destroys both doubles.
    CLASS-METHODS destroy.
    "! Empties both doubles - called in every setup.
    CLASS-METHODS clear.

    "! Inserts rows as active, saved runs.
    "!
    "! @parameter rows | Rows for the double of ZTBOE_RUN
    CLASS-METHODS given_active
      IMPORTING rows TYPE runs.

    "! Builds one open run.
    "!
    "! @parameter company_code | Company code of the run
    "! @parameter result       | Row ready for given_active
    CLASS-METHODS run
      IMPORTING company_code  TYPE zboe_company_code DEFAULT 'GR01'
      RETURNING VALUE(result) TYPE ztboe_run.

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

  METHOD given_active.
    cds_environment->insert_test_data( rows ).
  ENDMETHOD.

  METHOD run.
    result = VALUE #( run_uuid     = run_uuid
                      description  = 'Cutover'
                      company_code = company_code
                      posting_date = '20261231'
                      status       = zif_boe_migration=>run_status-open ).
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">The run through EML: status, header checks, instance authorization</p>
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
        company_code_denied  TYPE symsgno VALUE '032',
      END OF message.

    DATA authorization TYPE REF TO ltd_authorization.

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
    METHODS given_other_company_then_rej   FOR TESTING.
    METHODS given_no_date_then_rejected    FOR TESTING.
    METHODS when_created_then_status_open  FOR TESTING.
    METHODS given_own_run_then_changeable  FOR TESTING.
    METHODS given_other_run_then_no_change FOR TESTING.

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
    authorization = NEW #( ).
    lcl_run_factory=>inject_authorization( authorization ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_run_factory=>inject_authorization( VALUE #( ) ).
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
    DATA found TYPE abap_bool.

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

  METHOD given_other_company_then_rej.
    " ACT - the user of the double may post in GR01 only
    create_and_save( EXPORTING company_code = 'DE01'
                     IMPORTING failed       = DATA(failed)
                               reported     = DATA(reported) ).

    " ASSERT
    cl_abap_unit_assert=>assert_not_initial(
      act = failed-run
      msg = `A run for a company code the user may not post in must be rejected` ).
    assert_message( reported = reported
                    expected = message-company_code_denied ).
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

  METHOD given_own_run_then_changeable.
    " ARRANGE
    lth_run_doubles=>given_active( VALUE #( ( lth_run_doubles=>run( 'GR01' ) ) ) ).

    " ACT
    MODIFY ENTITIES OF zr_boemigrationrun
           ENTITY run
           UPDATE FIELDS ( description )
           WITH VALUE #( ( runuuid     = lth_run_doubles=>run_uuid
                           description = 'Changed' ) )
           FAILED DATA(failed).

    " ASSERT
    cl_abap_unit_assert=>assert_initial(
      act = failed-run
      msg = `A run of a company code the user may post in can be changed` ).
  ENDMETHOD.

  METHOD given_other_run_then_no_change.
    " ARRANGE - the user of the double may post in GR01 only
    lth_run_doubles=>given_active( VALUE #( ( lth_run_doubles=>run( 'DE01' ) ) ) ).

    " ACT
    MODIFY ENTITIES OF zr_boemigrationrun
           ENTITY run
           UPDATE FIELDS ( description )
           WITH VALUE #( ( runuuid     = lth_run_doubles=>run_uuid
                           description = 'Changed' ) )
           FAILED DATA(failed).

    " ASSERT
    cl_abap_unit_assert=>assert_not_initial(
      act = failed-run
      msg = `A run of a company code the user may not post in must not be changed` ).
    cl_abap_unit_assert=>assert_equals( act = failed-run[ 1 ]-%fail-cause
                                        exp = if_abap_behv=>cause-unauthorized
                                        msg = `The change must be refused for missing authorization` ).
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">Global authorization: who may create a run</p>
"! Calls the handler method directly, with a double of the authorization check.
"! @testing BDEF:ZR_BoEMigrationRun
CLASS ltc_global_authorization DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES auth_result    TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT zr_boemigrationrun\\run.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zr_boemigrationrun.

    DATA cut           TYPE REF TO lhc_run.
    DATA authorization TYPE REF TO ltd_authorization.

    METHODS setup.
    METHODS teardown.

    METHODS given_may_post_then_create_ok FOR TESTING.
    METHODS given_no_posting_then_denied  FOR TESTING.
    METHODS when_not_asked_then_untouched FOR TESTING.

ENDCLASS.


CLASS ltc_global_authorization IMPLEMENTATION.

  METHOD setup.
    authorization = NEW #( ).
    lcl_run_factory=>inject_authorization( authorization ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD teardown.
    lcl_run_factory=>inject_authorization( VALUE #( ) ).
  ENDMETHOD.

  METHOD given_may_post_then_create_ok.
    " ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.

    " ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %create = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = result-%create
                                        exp = if_abap_behv=>auth-allowed
                                        msg = `A user who may post in a company code may create a run` ).
    cl_abap_unit_assert=>assert_initial( act = reported-run
                                         msg = `A granted operation reports no message` ).
  ENDMETHOD.

  METHOD given_no_posting_then_denied.
    " ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    authorization->create_allowed = abap_false.

    " ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %create = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " ASSERT
    cl_abap_unit_assert=>assert_equals( act = result-%create
                                        exp = if_abap_behv=>auth-unauthorized
                                        msg = `A user who may not post anywhere must not create a run` ).
    cl_abap_unit_assert=>assert_equals( act = lines( reported-run )
                                        exp = 1
                                        msg = `The refusal is explained by one message` ).
  ENDMETHOD.

  METHOD when_not_asked_then_untouched.
    " ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    authorization->create_allowed = abap_false.

    " ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( )
      CHANGING  result                   = result
                reported                 = reported ).

    " ASSERT
    cl_abap_unit_assert=>assert_initial( act = result
                                         msg = `An operation the framework did not ask about gets no verdict` ).
  ENDMETHOD.

ENDCLASS.
