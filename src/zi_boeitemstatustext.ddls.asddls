// the texts of the fixed values of ZBOE_ITEM_STATUS, repeated here: the released view on fixed values
// (DDCDS_CUSTOMER_DOMAIN_VALUE_T) returned no rows for the domain on the development system
// Criticality as the UI reads it: 0 neutral, 1 negative, 2 critical, 3 positive
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status of a cheque of a migration run: text'
define view entity ZI_BoEItemStatusText
  as select from I_Language
{
  key cast( '10' as zboe_item_status ) as Status,
      cast( 'Ready' as abap.char( 40 ) ) as StatusText,
      3 as Criticality
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '20' as zboe_item_status ) as Status,
      cast( 'Has errors' as abap.char( 40 ) ) as StatusText,
      1 as Criticality
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '30' as zboe_item_status ) as Status,
      cast( 'In process' as abap.char( 40 ) ) as StatusText,
      0 as Criticality
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '40' as zboe_item_status ) as Status,
      cast( 'Migrated' as abap.char( 40 ) ) as StatusText,
      3 as Criticality
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( '50' as zboe_item_status ) as Status,
      cast( 'Failed' as abap.char( 40 ) ) as StatusText,
      1 as Criticality
}
where Language = 'E' // one row of the source per value
