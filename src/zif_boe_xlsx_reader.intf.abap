"! <p class="shorttext synchronized" lang="EN">Reads the cheques of a migration file</p>
"! Turns the uploaded Excel workbook into rows of text. What a cell means is
"! not decided here: {@link zif_boe_item_mapper} converts the text.
INTERFACE zif_boe_xlsx_reader
  PUBLIC.

  "! Reads sheet Cheques of the workbook.
  "! Row 1 names the columns. A column is found by its name, wherever it
  "! stands, and a column that the template does not know is skipped. Every
  "! further row with at least one value is returned with its row number in
  "! the sheet; values come without leading and trailing blanks.
  "!
  "! @parameter file_content | The workbook as it was uploaded
  "! @parameter result       | The rows below row 1 that have a value
  "! @raising   zcx_boe_file | The file is no workbook, sheet Cheques or a mandatory column is
  "!                           missing, or no row below row 1 has a value
  METHODS read
    IMPORTING file_content  TYPE xstring
    RETURNING VALUE(result) TYPE zif_boe_migration=>file_rows
    RAISING   zcx_boe_file.

ENDINTERFACE.
