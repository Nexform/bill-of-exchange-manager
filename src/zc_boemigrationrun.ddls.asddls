// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bill of exchange migration run'
@Metadata.allowExtensions: true
define root view entity ZC_BoEMigrationRun
  provider contract transactional_query
  as projection on ZR_BoEMigrationRun
{
  key RunUUID,
      Description,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CompanyCodeStdVH', element: 'CompanyCode' } } ]
      CompanyCode,
      PostingDate,
      Status,
      FileContent,
      FileMimeType,
      FileName,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
