// the texts of the fixed values of ZBOE_SEVERITY, repeated here: the released view on fixed values
// (DDCDS_CUSTOMER_DOMAIN_VALUE_T) returned no rows for the domain on the development system
// Criticality as the UI reads it: 0 neutral, 1 negative, 2 critical, 3 positive
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true // mandatory for a view with a union
@EndUserText.label: 'Severity of a check message: text'
define view entity ZI_BoESeverityText
  as select from I_Language
{
  key cast( 'E' as zboe_severity ) as Severity,
      cast( 'Error' as abap.char( 40 ) ) as SeverityText,
      1 as Criticality
}
where Language = 'E' // one row of the source per value
union all select from I_Language
{
  key cast( 'W' as zboe_severity ) as Severity,
      cast( 'Warning' as abap.char( 40 ) ) as SeverityText,
      2 as Criticality
}
where Language = 'E' // one row of the source per value
