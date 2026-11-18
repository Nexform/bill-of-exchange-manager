"! <p class="shorttext" lang="EN">Composition root of the behavior pool</p>
"! Handler classes have no constructor of their own, so their collaborators
"! are resolved here. The inject hook lets a test swap a collaborator for a
"! double; an unbound reference restores the production default.
CLASS lcl_run_factory DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! Master data of financial accounting that the checks of a run refer to.
    "!
    "! @parameter result | The master data access
    CLASS-METHODS master_data
      RETURNING VALUE(result) TYPE REF TO zif_boe_master_data.

    "! Test hook: replaces the production master data access until reset.
    "!
    "! @parameter master_data | Double to hand out, or unbound to restore the default
    CLASS-METHODS inject_master_data
      IMPORTING master_data TYPE REF TO zif_boe_master_data.

  PRIVATE SECTION.
    CLASS-DATA master_data_override TYPE REF TO zif_boe_master_data.
ENDCLASS.


CLASS lcl_run_factory IMPLEMENTATION.
  METHOD master_data.
    result = COND #( WHEN master_data_override IS BOUND
                     THEN master_data_override
                     ELSE NEW zcl_boe_master_data( ) ).
  ENDMETHOD.

  METHOD inject_master_data.
    master_data_override = master_data.
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">Behavior implementation of ZR_BoEMigrationRun</p>
"! The initial status and the checks of the run header.
"! Every validation reports into its own state area, so that the framework
"! replaces the messages of an earlier run instead of piling them up.
CLASS lhc_run DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    "! State area of validateDescription.
    CONSTANTS description_area TYPE string VALUE 'DESCRIPTION'.
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

    "! Rejects a run without a description.
    "!
    "! @parameter keys | Runs to check
    METHODS validatedescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR run~validatedescription.

    "! Rejects a run without a company code, or with one that does not exist.
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

  METHOD validatedescription.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( description )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    LOOP AT runs INTO DATA(run).
      " clears the messages of an earlier check of this run
      INSERT VALUE #( %tky        = run-%tky
                      %state_area = description_area )
             INTO TABLE reported-run.

      IF run-description IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      MESSAGE e032(zboe) INTO DATA(text) ##NEEDED.
      INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
      INSERT VALUE #( %tky                 = run-%tky
                      %state_area          = description_area
                      %msg                 = new_message( id       = sy-msgid
                                                          number   = sy-msgno
                                                          severity = if_abap_behv_message=>severity-error )
                      %element-description = if_abap_behv=>mk-on )
             INTO TABLE reported-run.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatecompanycode.
    DATA entered TYPE zif_boe_master_data=>company_code_keys.

    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( companycode )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs).

    " one read of the master data for all runs; several runs may name the same company code
    LOOP AT runs INTO DATA(named) WHERE companycode IS NOT INITIAL.
      INSERT VALUE #( company_code = named-companycode ) INTO TABLE entered.
    ENDLOOP.
    DATA(existing) = lcl_run_factory=>master_data( )->existing_company_codes( entered ).

    LOOP AT runs INTO DATA(run).
      " clears the messages of an earlier check of this run
      INSERT VALUE #( %tky        = run-%tky
                      %state_area = company_code_area )
             INTO TABLE reported-run.

      IF run-companycode IS INITIAL.
        MESSAGE e030(zboe) INTO DATA(text) ##NEEDED.
      ELSEIF NOT line_exists( existing[ company_code = run-companycode ] ).
        MESSAGE e033(zboe) WITH run-companycode INTO text.
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
