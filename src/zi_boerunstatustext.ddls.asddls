// the texts of the fixed values of ZBOE_RUN_STATUS, repeated here: the released view on fixed values
// (DDCDS_CUSTOMER_DOMAIN_VALUE_T) returned no rows for the domain on the development system
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status of a migration run: text'
define view entity ZI_BoERunStatusText
  as select from I_Language
{
  key cast( '10' as zboe_run_status ) as Status,
      cast( 'Open' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '20' as zboe_run_status ) as Status,
      cast( 'Queued' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '30' as zboe_run_status ) as Status,
      cast( 'In process' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '40' as zboe_run_status ) as Status,
      cast( 'Completed' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '50' as zboe_run_status ) as Status,
      cast( 'Completed with errors' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '90' as zboe_run_status ) as Status,
      cast( 'Cancelled' as abap.char( 40 ) ) as StatusText
}
where Language = 'E' // one row of the source per value
