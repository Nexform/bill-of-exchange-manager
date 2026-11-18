"! <p class="shorttext" lang="EN">Composition root of the behavior pool</p>
"! Handler classes have no constructor of their own, so their collaborators
"! are resolved here. The inject hook lets a test swap a collaborator for a
"! double; an unbound reference restores the production default.
CLASS lcl_run_factory DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! Authorization check the handler asks before it grants an operation.
    CLASS-METHODS authorization
      RETURNING VALUE(result) TYPE REF TO zif_boe_authorization.

    "! Test hook: replaces the production authorization check until reset.
    "!
    "! @parameter authorization | Double to hand out, or unbound to restore the default
    CLASS-METHODS inject_authorization
      IMPORTING authorization TYPE REF TO zif_boe_authorization.

  PRIVATE SECTION.
    CLASS-DATA authorization_override TYPE REF TO zif_boe_authorization.
ENDCLASS.


CLASS lcl_run_factory IMPLEMENTATION.
  METHOD authorization.
    result = COND #( WHEN authorization_override IS BOUND
                     THEN authorization_override
                     ELSE NEW zcl_boe_authorization( ) ).
  ENDMETHOD.

  METHOD inject_authorization.
    authorization_override = authorization.
  ENDMETHOD.
ENDCLASS.


" Forward declaration so the handler can name its test class as friend.
CLASS ltc_global_authorization DEFINITION DEFERRED FOR TESTING.

"! <p class="shorttext" lang="EN">Behavior implementation of ZR_BoEMigrationRun</p>
"! Authorizations, the initial status and the checks of the run header.
"! Every validation reports into its own state area, so that the framework
"! replaces the messages of an earlier run instead of piling them up.
CLASS lhc_run DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_global_authorization.
  PRIVATE SECTION.
    "! State area of validateCompanyCode.
    CONSTANTS company_code_area TYPE string VALUE 'COMPANY_CODE'.
    "! State area of validatePostingDate.
    CONSTANTS posting_date_area TYPE string VALUE 'POSTING_DATE'.

    "! Lets only users who may post in some company code create a run.
    "!
    "! @parameter requested_authorizations | Operations the framework asks about
    "! @parameter result                   | Verdict per requested operation
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR run RESULT result.

    "! Lets a run be changed or deleted only by users who may post in its
    "! company code.
    "!
    "! @parameter keys                     | Runs the framework asks about
    "! @parameter requested_authorizations | Operations the framework asks about
    "! @parameter result                   | Verdict per run
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR run RESULT result.

    "! Gives a new run the status open.
    "!
    "! @parameter keys | Runs that were created
    METHODS setinitialstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR run~setinitialstatus.

    "! Rejects a run without a company code, or with one the user may not
    "! post in.
    "!
    "! @parameter keys | Runs to check
    METHODS validatecompanycode FOR VALIDATE ON SAVE
      IMPORTING keys FOR run~validatecompanycode.

    "! Rejects a run without a posting date.
    "!
    "! @parameter keys | Runs to check
    METHODS validatepostingdate FOR VALIDATE ON SAVE
      IMPORTING keys FOR run~validatepostingdate.
ENDCLASS.


CLASS lhc_run IMPLEMENTATION.
  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-off.
      RETURN.
    ENDIF.

    IF lcl_run_factory=>authorization( )->is_create_allowed( ) = abap_true.
      result-%create = if_abap_behv=>auth-allowed.
      RETURN.
    ENDIF.

    result-%create = if_abap_behv=>auth-unauthorized.

    MESSAGE e033(zboe) INTO DATA(text) ##NEEDED.
    INSERT VALUE #( %global = if_abap_behv=>mk-on
                    %msg    = new_message( id       = sy-msgid
                                           number   = sy-msgno
                                           severity = if_abap_behv_message=>severity-error ) )
           INTO TABLE reported-run.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( companycode )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs)
         FAILED failed.

    DATA(authorization) = lcl_run_factory=>authorization( ).

    LOOP AT runs INTO DATA(run).
      DATA(verdict) = COND #( WHEN authorization->is_change_allowed( run-companycode ) = abap_true
                              THEN if_abap_behv=>auth-allowed
                              ELSE if_abap_behv=>auth-unauthorized ).

      INSERT VALUE #( %tky         = run-%tky
                      %update      = verdict
                      %action-edit = verdict
                      %delete      = verdict )
             INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD setinitialstatus.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( status )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    MODIFY ENTITIES OF zr_boemigrationrun IN LOCAL MODE
           ENTITY run
           UPDATE FIELDS ( status )
           WITH VALUE #( FOR run IN runs
                         WHERE ( status IS INITIAL )
                         ( %tky   = run-%tky
                           status = zif_boe_migration=>run_status-open ) ).
  ENDMETHOD.

  METHOD validatecompanycode.
    DATA text TYPE string ##NEEDED.

    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( companycode )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    DATA(authorization) = lcl_run_factory=>authorization( ).

    LOOP AT runs INTO DATA(run).
      " clears the messages of an earlier check of this run
      INSERT VALUE #( %tky        = run-%tky
                      %state_area = company_code_area )
             INTO TABLE reported-run.

      IF run-companycode IS INITIAL.
        MESSAGE e030(zboe) INTO text.
      ELSEIF authorization->is_change_allowed( run-companycode ) = abap_false.
        MESSAGE e032(zboe) WITH run-companycode INTO text.
      ELSE.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
      INSERT VALUE #( %tky                 = run-%tky
                      %state_area          = company_code_area
                      %msg                 = new_message( id       = sy-msgid
                                                          number   = sy-msgno
                                                          severity = if_abap_behv_message=>severity-error
                                                          v1       = sy-msgv1 )
                      %element-companycode = if_abap_behv=>mk-on )
             INTO TABLE reported-run.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatepostingdate.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( postingdate )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    LOOP AT runs INTO DATA(run).
      " clears the messages of an earlier check of this run
      INSERT VALUE #( %tky        = run-%tky
                      %state_area = posting_date_area )
             INTO TABLE reported-run.

      IF run-postingdate IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      MESSAGE e031(zboe) INTO DATA(text) ##NEEDED.
      INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
      INSERT VALUE #( %tky                 = run-%tky
                      %state_area          = posting_date_area
                      %msg                 = new_message( id       = sy-msgid
                                                          number   = sy-msgno
                                                          severity = if_abap_behv_message=>severity-error )
                      %element-postingdate = if_abap_behv=>mk-on )
             INTO TABLE reported-run.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
