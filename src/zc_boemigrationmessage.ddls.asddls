// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Message about a cheque of a run'
@Metadata.allowExtensions: true
define view entity ZC_BoEMigrationMessage
  as projection on ZR_BoEMigrationMessage
{
  key MessageUUID,
      ItemUUID,
      RunUUID,
      @ObjectModel.text.element: [ 'SeverityText' ]
      Severity,
      @Semantics.text: true
      _SeverityText.SeverityText as SeverityText,
      _SeverityText.Criticality  as SeverityCriticality,
      ColumnName,
      MessageID,
      MessageNumber,
      MessageVariable1,
      MessageVariable2,
      MessageVariable3,
      MessageVariable4,
      MessageText,
      LocalLastChangedAt,
      _Item : redirected to parent ZC_BoEMigrationItem,
      _Run  : redirected to ZC_BoEMigrationRun
}
