"! <p class="shorttext synchronized" lang="EN">Constants of the migration of bills of exchange</p>
"! Values that the migration workbench and its background processing share.
INTERFACE zif_boe_migration
  PUBLIC.

  CONSTANTS:
    "! The statuses of a migration run - the fixed values of {@link DOMA:zboe_run_status}.
    BEGIN OF run_status,
      "! The file can be uploaded, checked and corrected.
      open                  TYPE zboe_run_status VALUE '10',
      "! Waiting for the background processing; the run is locked for changes.
      queued                TYPE zboe_run_status VALUE '20',
      "! The background processing is creating the bills.
      in_process            TYPE zboe_run_status VALUE '30',
      "! Every item that was not excluded has become a bill.
      completed             TYPE zboe_run_status VALUE '40',
      "! Some items failed; they can be corrected and processed again.
      completed_with_errors TYPE zboe_run_status VALUE '50',
      "! Given up before any bill was created.
      cancelled             TYPE zboe_run_status VALUE '90',
    END OF run_status.

ENDINTERFACE.
