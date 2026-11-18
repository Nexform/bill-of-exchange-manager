"! <p class="shorttext synchronized" lang="EN">Finds the posting adapter of the edition</p>
"! Reads the class name of the posting adapter from the adapter registry
"! {@link ztboe_adapter} and creates the object by that name. The name is data,
"! never source code of the core: a static reference would tie the core to one
"! edition.
CLASS zcl_boe_posting_provider DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_boe_posting_provider.

  PRIVATE SECTION.
    "! Fixed value of {@link DOMA:zboe_adapter_role}.
    CONSTANTS posting_role TYPE zboe_adapter_role VALUE 'POSTING'.

    METHODS create_adapter
      IMPORTING class_name    TYPE zboe_class_name
      RETURNING VALUE(result) TYPE REF TO zif_boe_posting
      RAISING   zcx_boe_adapter.

ENDCLASS.



CLASS zcl_boe_posting_provider IMPLEMENTATION.

  METHOD zif_boe_posting_provider~posting.
    SELECT SINGLE FROM ztboe_adapter
      FIELDS class_name
      WHERE adapter_role = @posting_role
      INTO @DATA(class_name).

    IF sy-subrc <> 0.
      result = NEW zcl_boe_no_posting( ).
      RETURN.
    ENDIF.

    result = create_adapter( class_name ).
  ENDMETHOD.

  METHOD zif_boe_posting_provider~register.
    DATA(registration) = VALUE ztboe_adapter( adapter_role = posting_role
                                              class_name   = to_upper( class_name ) ).

    " proves that the class can serve before the registry points to it
    create_adapter( registration-class_name ).

    MODIFY ztboe_adapter FROM @registration.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_boe_adapter
        MESSAGE e012(zboe) WITH registration-class_name
        EXPORTING
          class_name = registration-class_name.
    ENDIF.
  ENDMETHOD.

  METHOD create_adapter.
    DATA adapter TYPE REF TO object.

    TRY.
        CREATE OBJECT adapter TYPE (class_name).
        result = CAST #( adapter ).
      CATCH cx_sy_create_object_error cx_sy_dyn_call_error INTO DATA(creation_error).
        RAISE EXCEPTION TYPE zcx_boe_adapter
          MESSAGE e010(zboe) WITH class_name
          EXPORTING
            previous   = creation_error
            class_name = class_name.
      CATCH cx_sy_move_cast_error INTO DATA(cast_error).
        RAISE EXCEPTION TYPE zcx_boe_adapter
          MESSAGE e011(zboe) WITH class_name
          EXPORTING
            previous   = cast_error
            class_name = class_name.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
