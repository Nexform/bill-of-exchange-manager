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

    "! The check of the file of a run, with its reader, mapper and validator.
    "!
    "! @parameter result | The check
    CLASS-METHODS run_check
      RETURNING VALUE(result) TYPE REF TO zif_boe_run_check.

    "! Test hook: replaces the production check until reset.
    "!
    "! @parameter run_check | Double to hand out, or unbound to restore the default
    CLASS-METHODS inject_run_check
      IMPORTING run_check TYPE REF TO zif_boe_run_check.

  PRIVATE SECTION.
    CLASS-DATA master_data_override TYPE REF TO zif_boe_master_data.
    CLASS-DATA run_check_override TYPE REF TO zif_boe_run_check.
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

  METHOD run_check.
    IF run_check_override IS BOUND.
      result = run_check_override.
      RETURN.
    ENDIF.

    result = NEW zcl_boe_run_check(
                   reader    = NEW zcl_boe_xlsx_reader( )
                   mapper    = NEW zcl_boe_item_mapper( )
                   validator = NEW zcl_boe_item_validator( master_data  = master_data( )
                                                           status_rules = NEW zcl_boe_status_rules( ) ) ).
  ENDMETHOD.

  METHOD inject_run_check.
    run_check_override = run_check.
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">Behavior implementation of ZR_BoEMigrationRun</p>
"! The initial status and the checks of the run header, and the check of the
"! migration file, which turns the file into the cheques of the run.
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

    " derived types can be declared with TYPES and DATA only, not in the signature of a method
    "! A run as READ ENTITIES returns it.
    TYPES run_read TYPE STRUCTURE FOR READ RESULT zr_boemigrationrun\\run.
    "! Runs whose cheques are to be read.
    TYPES runs_with_cheques TYPE TABLE FOR READ IMPORT zr_boemigrationrun\\run\_items.

    "! Grants every operation: an operation that gets no verdict stays allowed.
    "! Authorizations are added as the last step before the first productive
    "! use - this method and an access control of the views are their place.
    "!
    "! @parameter requested_authorizations | Operations the framework asks about
    "! @parameter result                   | Verdict per requested operation - left empty
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR run RESULT result.

    "! Tells for every run whether its file can be checked now.
    "!
    "! @parameter keys               | Runs the framework asks about
    "! @parameter requested_features | Features the framework asks about
    "! @parameter result             | Action checkFile per run: enabled or disabled
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR run RESULT result.

    "! Reads the file of a run and replaces its cheques by the cheques of the file.
    "! A file that is unusable as a whole fails the action and leaves the cheques
    "! of an earlier check as they are.
    "!
    "! @parameter keys   | Runs whose file is to be checked
    "! @parameter result | The runs after the check
    METHODS checkfile FOR MODIFY
      IMPORTING keys FOR ACTION run~checkfile RESULT result.

    "! Removes the cheques of a run whose file or company code has changed.
    "!
    "! @parameter keys | Runs that were changed
    METHODS discardcheck FOR DETERMINE ON MODIFY
      IMPORTING keys FOR run~discardcheck.

    "! Replaces the cheques of a run by the outcome of a check of its file.
    "!
    "! @parameter run     | The run
    "! @parameter outcome | Cheques and messages of the file
    "! @parameter result  | abap_true when everything was stored
    METHODS store_outcome
      IMPORTING run           TYPE run_read
                outcome       TYPE zif_boe_migration=>check_result
      RETURNING VALUE(result) TYPE abap_bool.

    "! Deletes the cheques of runs; their messages go with them.
    "!
    "! @parameter runs | Runs whose cheques are deleted
    METHODS delete_cheques
      IMPORTING runs TYPE runs_with_cheques.

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

  METHOD get_instance_features.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( status filename )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs)
         FAILED failed.

    LOOP AT runs INTO DATA(run).
      " the check reads the file that is saved: a draft is saved first. The name stands for the file -
      " reading the content itself only to see whether there is one would be expensive
      DATA(can_be_checked) = xsdbool(     run-%is_draft = if_abap_behv=>mk-off
                                      AND run-status    = zif_boe_migration=>run_status-open
                                      AND run-filename IS NOT INITIAL ).

      INSERT VALUE #( %tky              = run-%tky
                      %action-checkfile = COND #( WHEN can_be_checked = abap_true
                                                  THEN if_abap_behv=>fc-o-enabled
                                                  ELSE if_abap_behv=>fc-o-disabled ) )
             INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

  METHOD checkfile.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         FIELDS ( filecontent companycode )
         WITH CORRESPONDING #( keys )
         RESULT DATA(runs)
         FAILED failed.

    LOOP AT runs INTO DATA(run).
      TRY.
          DATA(outcome) = lcl_run_factory=>run_check( )->check( file_content = run-filecontent
                                                                company_code = run-companycode ).
        CATCH zcx_boe_file INTO DATA(unusable).
          INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
          INSERT VALUE #( %tky = run-%tky
                          %msg = new_message( id       = unusable->if_t100_message~t100key-msgid
                                              number   = unusable->if_t100_message~t100key-msgno
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = unusable->if_t100_dyn_msg~msgv1
                                              v2       = unusable->if_t100_dyn_msg~msgv2 ) )
                 INTO TABLE reported-run.
          CONTINUE.
      ENDTRY.

      IF store_outcome( run     = run
                        outcome = outcome ) = abap_false.
        INSERT VALUE #( %tky = run-%tky ) INTO TABLE failed-run.
        CONTINUE.
      ENDIF.

      DATA(cheque_count) = |{ outcome-item_count }|.
      DATA(error_count) = |{ outcome-error_count }|.
      MESSAGE s044(zboe) WITH cheque_count error_count INTO DATA(text) ##NEEDED.
      INSERT VALUE #( %tky = run-%tky
                      %msg = new_message( id       = sy-msgid
                                          number   = sy-msgno
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = sy-msgv1
                                          v2       = sy-msgv2 ) )
             INTO TABLE reported-run.
    ENDLOOP.

    " the action returns the whole run, so the whole run is read
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(checked_runs).

    result = VALUE #( FOR checked_run IN checked_runs
                      ( %tky   = checked_run-%tky
                        %param = checked_run ) ).
  ENDMETHOD.

  METHOD discardcheck.
    delete_cheques( CORRESPONDING #( keys ) ).

    MODIFY ENTITIES OF zr_boemigrationrun IN LOCAL MODE
           ENTITY run
           UPDATE FIELDS ( itemcount errorcount )
           WITH VALUE #( FOR key IN keys
                         ( %tky = key-%tky ) ).
  ENDMETHOD.

  METHOD store_outcome.
    DATA cheques TYPE TABLE FOR CREATE zr_boemigrationrun\\run\_items.
    DATA messages TYPE TABLE FOR CREATE zr_boemigrationrun\\item\_messages.

    delete_cheques( VALUE #( ( %tky = run-%tky ) ) ).

    " a cheque is known by its position in the file until the framework has given it a key
    cheques = VALUE #( ( %tky    = run-%tky
                         %target = VALUE #( FOR checked IN outcome-items INDEX INTO cheque_index
                                            ( %cid              = |CHEQUE{ cheque_index }|
                                              %is_draft         = run-%is_draft
                                              rownumber         = checked-item-row_number
                                              itemstatus        = checked-status
                                              boenumber         = checked-item-boe_number
                                              customer          = checked-item-customer
                                              amount            = checked-item-amount
                                              currency          = checked-item-currency
                                              duedate           = checked-item-due_date
                                              issuedate         = checked-item-issue_date
                                              targetstatus      = checked-item-target_status
                                              drawername        = checked-item-drawer_name
                                              draweebankcountry = checked-item-drawee_bank_country
                                              draweebank        = checked-item-drawee_bank
                                              draweebankname    = checked-item-drawee_bank_name
                                              draweeaccount     = checked-item-drawee_account
                                              housebank         = checked-item-house_bank
                                              housebankaccount  = checked-item-house_bank_account
                                              isregisteronly    = checked-item-is_register_only
                                              legacyreference   = checked-item-legacy_reference
                                              note              = checked-item-note ) ) ) ).

    LOOP AT outcome-items INTO DATA(reported_cheque) WHERE messages IS NOT INITIAL.
      DATA(cheque_position) = sy-tabix.

      INSERT VALUE #( %cid_ref  = |CHEQUE{ cheque_position }|
                      %is_draft = run-%is_draft
                      %target   = VALUE #( FOR message IN reported_cheque-messages INDEX INTO message_index
                                           ( %cid             = |CHEQUE{ cheque_position }MESSAGE{ message_index }|
                                             %is_draft        = run-%is_draft
                                             runuuid          = run-runuuid
                                             severity         = message-severity
                                             columnname       = message-column
                                             messageid        = message-id
                                             messagenumber    = message-number
                                             messagevariable1 = message-variable_1
                                             messagevariable2 = message-variable_2
                                             messagevariable3 = message-variable_3
                                             messagevariable4 = message-variable_4
                                             messagetext      = message-text ) ) )
             INTO TABLE messages.
    ENDLOOP.

    MODIFY ENTITIES OF zr_boemigrationrun IN LOCAL MODE
           ENTITY run
           CREATE BY \_items
           FIELDS ( rownumber itemstatus boenumber customer amount currency duedate issuedate targetstatus
                    drawername draweebankcountry draweebank draweebankname draweeaccount housebank
                    housebankaccount isregisteronly legacyreference note )
           WITH cheques
           ENTITY item
           CREATE BY \_messages
           FIELDS ( runuuid severity columnname messageid messagenumber messagevariable1 messagevariable2
                    messagevariable3 messagevariable4 messagetext )
           WITH messages
           FAILED DATA(create_failed).

    MODIFY ENTITIES OF zr_boemigrationrun IN LOCAL MODE
           ENTITY run
           UPDATE FIELDS ( itemcount errorcount )
           WITH VALUE #( ( %tky       = run-%tky
                           itemcount  = outcome-item_count
                           errorcount = outcome-error_count ) )
           FAILED DATA(update_failed).

    result = xsdbool( create_failed IS INITIAL AND update_failed IS INITIAL ).
  ENDMETHOD.

  METHOD delete_cheques.
    READ ENTITIES OF zr_boemigrationrun IN LOCAL MODE
         ENTITY run BY \_items
         FIELDS ( itemuuid )
         WITH runs
         RESULT DATA(cheques).

    IF cheques IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_boemigrationrun IN LOCAL MODE
           ENTITY item
           DELETE FROM VALUE #( FOR cheque IN cheques
                                ( %tky = cheque-%tky ) ).
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
