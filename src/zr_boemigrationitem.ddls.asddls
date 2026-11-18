// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cheque of a bill of exchange migration run'
define view entity ZR_BoEMigrationItem
  as select from ztboe_item
  association        to parent ZR_BoEMigrationRun as _Run        on $projection.RunUUID = _Run.RunUUID
  composition [0..*] of ZR_BoEMigrationMessage    as _Messages
  association [0..1] to ZI_BoEItemStatusText      as _StatusText on $projection.ItemStatus = _StatusText.Status
{
  key item_uuid             as ItemUUID,
      run_uuid              as RunUUID,
      row_number            as RowNumber,
      item_status           as ItemStatus,
      boe_number            as BoENumber,
      customer              as Customer,
      @Semantics.amount.currencyCode: 'Currency'
      amount                as Amount,
      currency              as Currency,
      due_date              as DueDate,
      issue_date            as IssueDate,
      target_status         as TargetStatus,
      drawer_name           as DrawerName,
      drawee_bank_country   as DraweeBankCountry,
      drawee_bank           as DraweeBank,
      drawee_bank_name      as DraweeBankName,
      drawee_account        as DraweeAccount,
      house_bank            as HouseBank,
      house_bank_account    as HouseBankAccount,
      register_only         as IsRegisterOnly,
      legacy_reference      as LegacyReference,
      note                  as Note,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true   // etag master
      local_last_changed_at as LocalLastChangedAt,
      _Run,
      _Messages,
      _StatusText
}
