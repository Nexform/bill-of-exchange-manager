// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Message about a cheque of a migration run'
define view entity ZR_BoEMigrationMessage
  as select from ztboe_msg
  association        to parent ZR_BoEMigrationItem as _Item         on $projection.ItemUUID = _Item.ItemUUID
  association [1..1] to ZR_BoEMigrationRun         as _Run          on $projection.RunUUID = _Run.RunUUID // lock master
  association [0..1] to ZI_BoESeverityText         as _SeverityText on $projection.Severity = _SeverityText.Severity
{
  key message_uuid          as MessageUUID,
      item_uuid             as ItemUUID,
      run_uuid              as RunUUID,
      severity              as Severity,
      column_name           as ColumnName,
      message_id            as MessageID,
      message_number        as MessageNumber,
      variable_1            as MessageVariable1,
      variable_2            as MessageVariable2,
      variable_3            as MessageVariable3,
      variable_4            as MessageVariable4,
      message_text          as MessageText,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true   // etag master
      local_last_changed_at as LocalLastChangedAt,
      _Item,
      _Run,
      _SeverityText
}
