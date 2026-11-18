// no access control yet: authorizations are added as the last step before the first productive use
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bill of exchange migration run'
define root view entity ZR_BoEMigrationRun
  as select from ztboe_run
  composition [0..*] of ZR_BoEMigrationItem as _Items
  association [0..1] to ZI_BoERunStatusText as _StatusText on $projection.Status = _StatusText.Status
{
  key run_uuid              as RunUUID,
      description           as Description,
      company_code          as CompanyCode,
      posting_date          as PostingDate,
      status                as Status,
      @Semantics.largeObject: { mimeType: 'FileMimeType',
                                fileName: 'FileName',
                                acceptableMimeTypes: [ 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ], // .xlsx
                                contentDispositionPreference: #ATTACHMENT }
      file_content          as FileContent,
      @Semantics.mimeType: true
      file_mime_type        as FileMimeType,
      file_name             as FileName,
      item_count            as ItemCount,
      error_count           as ErrorCount,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true                // total etag
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true   // etag master
      local_last_changed_at as LocalLastChangedAt,
      _Items,
      _StatusText
}
