"! <p class="shorttext" lang="EN">Behavior implementation of ZR_BoEMigrationRun</p>
"! The initial status and the checks of the run header.
"! Every validation reports into its own state area, so that the framework
"! replaces the messages of an earlier run instead of piling them up.
CLASS lhc_run DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    "! State area of validateCompanyCode.
    CONSTANTS company_code_area TYPE string VALUE 'COMPANY_CODE'.
    "! State area of validatePostingDate.
    CONSTANTS posting_date_area TYPE string VALUE 'POSTING_DATE'.

    "! Grants every operation: an operation that gets no verdict stays allowed.
    "! Authorizations are added as the last step before the first productive
    "! use - this method and an access control of the views are their place.
    "!
    "! @parameter requested_authorizations | Operations the framework asks about
    "! @parameter result                   | Verdict per requested operation - left empty
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR run RESULT result.

    "! Gives a new run the status open.
    "!
    "! @parameter keys | Runs that were created
    METHODS setinitialstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR run~setinitialstatus.

    "! Rejects a run without a company code.
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
    " no verdict on purpose - see the declaration
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
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( companycode )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    LOOP AT runs INTO DATA(run).
      " clears the messages of an earlier check of this run
      INSERT VALUE #( %tky        = run-%tky
                      %state_area = company_code_area )
             INTO TABLE reported-run.

      IF run-companycode IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      MESSAGE e030(zboe) INTO DATA(text) ##NEEDED.
      INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
      INSERT VALUE #( %tky                 = run-%tky
                      %state_area          = company_code_area
                      %msg                 = new_message( id       = sy-msgid
                                                          number   = sy-msgno
                                                          severity = if_abap_behv_message=>severity-error )
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
