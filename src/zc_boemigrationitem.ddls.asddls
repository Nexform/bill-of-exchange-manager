// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cheque of a bill of exchange migration run'
@Metadata.allowExtensions: true
define view entity ZC_BoEMigrationItem
  as projection on ZR_BoEMigrationItem
{
  key ItemUUID,
      RunUUID,
      RowNumber,
      @ObjectModel.text.element: [ 'ItemStatusText' ]
      ItemStatus,
      @Semantics.text: true
      _StatusText.StatusText  as ItemStatusText,
      _StatusText.Criticality as ItemStatusCriticality,
      BoENumber,
      Customer,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      Currency,
      DueDate,
      IssueDate,
      TargetStatus,
      DrawerName,
      DraweeBankCountry,
      DraweeBank,
      DraweeBankName,
      DraweeAccount,
      HouseBank,
      HouseBankAccount,
      IsRegisterOnly,
      LegacyReference,
      Note,
      LocalLastChangedAt,
      _Run      : redirected to parent ZC_BoEMigrationRun,
      _Messages : redirected to composition child ZC_BoEMigrationMessage
}
