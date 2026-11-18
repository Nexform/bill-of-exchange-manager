"! <p class="shorttext synchronized" lang="EN">Converts a row of the migration file into a cheque</p>
"! Everything that can be said about a row by looking at its cells alone:
"! which cells must have a value, and whether a value is a date, an amount or
"! a text that fits its field. Checks that need other rows or master data
"! belong to {@link zif_boe_item_validator}.
INTERFACE zif_boe_item_mapper
  PUBLIC.

  TYPES:
    "! A converted row and what was wrong with its cells.
    BEGIN OF mapped_item,
      item     TYPE zif_boe_migration=>item,
      messages TYPE zif_boe_migration=>messages,
    END OF mapped_item.

  "! Converts the cells of a row.
  "! A cell that cannot be converted leaves its field initial and adds a
  "! message that names the column and quotes the cell.
  "!
  "! @parameter row    | The row as {@link zif_boe_xlsx_reader} returned it
  "! @parameter result | The cheque and the messages about its cells
  METHODS map
    IMPORTING row           TYPE zif_boe_migration=>file_row
    RETURNING VALUE(result) TYPE mapped_item.

ENDINTERFACE.
