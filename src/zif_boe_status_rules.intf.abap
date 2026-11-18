"! <p class="shorttext synchronized" lang="EN">Status rules of a bill of exchange</p>
"! The life cycle of a received cheque or bill of exchange: which status may
"! follow which, where the life cycle ends and in which statuses a bill may be
"! taken over from a legacy system.
INTERFACE zif_boe_status_rules
  PUBLIC.

  CONSTANTS:
    "! The statuses of a bill of exchange - the fixed values of {@link DOMA:zboe_status}.
    BEGIN OF status,
      "! Received and held by the company.
      in_portfolio           TYPE zboe_status VALUE '10',
      "! Passed on to a supplier as payment.
      endorsed               TYPE zboe_status VALUE '20',
      "! Deposited with a bank that collects it at maturity.
      at_bank_for_collection TYPE zboe_status VALUE '30',
      "! Deposited with a bank as security for a loan.
      at_bank_as_collateral  TYPE zboe_status VALUE '40',
      "! Paid. The life cycle ends.
      collected              TYPE zboe_status VALUE '50',
      "! Presented and not paid.
      dishonoured            TYPE zboe_status VALUE '60',
      "! Handed back to the customer or replaced. The life cycle ends.
      returned               TYPE zboe_status VALUE '70',
      "! Entered by mistake and taken out again. The life cycle ends.
      cancelled              TYPE zboe_status VALUE '90',
    END OF status.

  "! Tells whether a bill in one status may move to another.
  "! A bill that is not in the register yet has no status to move from: use
  "! {@link zif_boe_status_rules.METH:is_migration_target} for its first status.
  "!
  "! @parameter previous_status | Status the bill is in
  "! @parameter new_status      | Status the bill is to get
  "! @parameter result          | abap_true when the change is part of the life cycle
  METHODS is_allowed
    IMPORTING previous_status TYPE zboe_status
              new_status      TYPE zboe_status
    RETURNING VALUE(result)   TYPE abap_bool.

  "! Tells whether the life cycle of a bill ends in a status.
  "!
  "! @parameter status | Status to look at
  "! @parameter result | abap_true when no further change is possible
  METHODS is_final
    IMPORTING status        TYPE zboe_status
    RETURNING VALUE(result) TYPE abap_bool.

  "! Tells whether a bill may enter the register in a status when it is taken
  "! over from a legacy system.
  "!
  "! @parameter status | Status the migrated bill is to get
  "! @parameter result | abap_true when open bills are migrated in this status
  METHODS is_migration_target
    IMPORTING status        TYPE zboe_status
    RETURNING VALUE(result) TYPE abap_bool.

ENDINTERFACE.
