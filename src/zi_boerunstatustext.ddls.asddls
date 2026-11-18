// texts of the fixed values of a domain: no business data to protect
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status of a migration run: text'
@ObjectModel.dataCategory: #TEXT
define view entity ZI_BoERunStatusText
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZBOE_RUN_STATUS' ) // domain of the run status
{
      // a fixed value is delivered ten characters long; the status has two
  key cast( left( value_low, 2 ) as zboe_run_status preserving type ) as Status,
      @Semantics.language: true
  key language                                                        as Language,
      @Semantics.text: true
      text                                                            as StatusText
}
