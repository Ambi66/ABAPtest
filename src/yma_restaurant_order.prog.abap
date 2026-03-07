*&---------------------------------------------------------------------*
*& Report  YMA_RESTAURANT_ORDER
*& Restaurant Order Entry / Menu Display
*&---------------------------------------------------------------------*
*& Usage:
*&   - Check "Display Menu" to browse available items with their IDs.
*&   - Uncheck "Display Menu", fill in table/customer and up to 5 order
*&     items, then execute to save the order and print a receipt.
*&---------------------------------------------------------------------*
REPORT yma_restaurant_order.

*----------------------------------------------------------------------*
* Global data
*----------------------------------------------------------------------*
DATA:
  gs_cust         TYPE yma_rest_cust,
  gs_ord          TYPE yma_rest_ord,
  gs_ordi         TYPE yma_rest_ordi,
  gs_menu         TYPE yma_rest_menu,
  gt_menu         TYPE TABLE OF yma_rest_menu,
  gt_ordi         TYPE TABLE OF yma_rest_ordi,
  lv_order_id     TYPE yma_rest_ord-order_id,
  lv_cust_id      TYPE yma_rest_cust-cust_id,
  lv_pos          TYPE yma_rest_ordi-item_pos,
  lv_total        TYPE yma_rest_ord-total_amt,
  lv_waers        TYPE yma_rest_ord-waers.

*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE lv_tit1.
  PARAMETERS: p_show AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE lv_tit2.
  PARAMETERS: p_table TYPE yma_rest_ord-table_no.
  PARAMETERS: p_cname TYPE yma_rest_cust-cust_name.
  PARAMETERS: p_phone TYPE yma_rest_cust-phone.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE lv_tit3.
  PARAMETERS: p_itm1  TYPE yma_rest_menu-item_id,
              p_qty1  TYPE yma_rest_ordi-quantity DEFAULT '001'.
  PARAMETERS: p_itm2  TYPE yma_rest_menu-item_id,
              p_qty2  TYPE yma_rest_ordi-quantity DEFAULT '001'.
  PARAMETERS: p_itm3  TYPE yma_rest_menu-item_id,
              p_qty3  TYPE yma_rest_ordi-quantity DEFAULT '001'.
  PARAMETERS: p_itm4  TYPE yma_rest_menu-item_id,
              p_qty4  TYPE yma_rest_ordi-quantity DEFAULT '001'.
  PARAMETERS: p_itm5  TYPE yma_rest_menu-item_id,
              p_qty5  TYPE yma_rest_ordi-quantity DEFAULT '001'.
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
* INITIALIZATION  –  set block titles
*----------------------------------------------------------------------*
INITIALIZATION.
  lv_tit1 = 'Display Options'.
  lv_tit2 = 'Table and Customer'.
  lv_tit3 = 'Order Items (Item ID + Quantity)'.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN  –  validate input for order mode
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CHECK p_show = space.
  IF p_table IS INITIAL.
    MESSAGE 'Please enter a table number.' TYPE 'E'.
  ENDIF.
  IF p_cname IS INITIAL.
    MESSAGE 'Please enter the customer name.' TYPE 'E'.
  ENDIF.
  IF p_itm1 IS INITIAL AND p_itm2 IS INITIAL AND
     p_itm3 IS INITIAL AND p_itm4 IS INITIAL AND
     p_itm5 IS INITIAL.
    MESSAGE 'Please enter at least one menu item.' TYPE 'E'.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
  IF p_show = abap_true.
    PERFORM display_menu.
  ELSE.
    PERFORM enter_order.
  ENDIF.

*&---------------------------------------------------------------------*
*& Form DISPLAY_MENU
*& Reads all available menu items and prints them grouped by category.
*&---------------------------------------------------------------------*
FORM display_menu.
  DATA: lv_last_cat TYPE yma_rest_menu-catid,
        ls_cat      TYPE yma_rest_cat.

  SELECT * FROM yma_rest_menu
    INTO TABLE gt_menu
    WHERE available = @abap_true
    ORDER BY catid ASCENDING, item_id ASCENDING.

  IF sy-subrc <> 0.
    WRITE: / 'No menu items found. Please maintain table YMA_REST_MENU.'.
    RETURN.
  ENDIF.

  ULINE.
  FORMAT COLOR COL_HEADING INTENSIFIED ON.
  WRITE: /1 'RESTAURANT MENU'.
  FORMAT COLOR OFF INTENSIFIED OFF.
  ULINE.
  WRITE: /1 'Item-ID', 10 'Category', 22 'Description', 64 'Price', 75 'Curr'.
  ULINE.

  LOOP AT gt_menu INTO gs_menu.
    IF gs_menu-catid <> lv_last_cat.
      lv_last_cat = gs_menu-catid.
      SELECT SINGLE catname INTO ls_cat-catname
        FROM yma_rest_cat
        WHERE catid = gs_menu-catid.
      WRITE: /.
      FORMAT COLOR COL_GROUP INTENSIFIED ON.
      WRITE: /1 ls_cat-catname.
      FORMAT COLOR OFF INTENSIFIED OFF.
    ENDIF.
    WRITE: /1  gs_menu-item_id,
           10  gs_menu-catid,
           22  gs_menu-item_name,
           64  gs_menu-price CURRENCY gs_menu-waers,
           75  gs_menu-waers.
  ENDLOOP.
  ULINE.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form ENTER_ORDER
*& Orchestrates validation, customer/order creation and confirmation.
*&---------------------------------------------------------------------*
FORM enter_order.
  CLEAR: gt_ordi, lv_pos, lv_total.
  lv_waers = 'EUR'.

  PERFORM validate_and_add_item USING p_itm1 p_qty1.
  PERFORM validate_and_add_item USING p_itm2 p_qty2.
  PERFORM validate_and_add_item USING p_itm3 p_qty3.
  PERFORM validate_and_add_item USING p_itm4 p_qty4.
  PERFORM validate_and_add_item USING p_itm5 p_qty5.

  PERFORM get_or_create_customer.
  PERFORM create_order.
  PERFORM display_confirmation.
  COMMIT WORK.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form VALIDATE_AND_ADD_ITEM
*& Checks that the item exists and is available, then appends it to
*& the internal order-items table and accumulates the running total.
*&---------------------------------------------------------------------*
FORM validate_and_add_item
  USING pv_item_id TYPE yma_rest_menu-item_id
        pv_qty     TYPE yma_rest_ordi-quantity.

  CHECK pv_item_id IS NOT INITIAL.

  SELECT SINGLE * FROM yma_rest_menu INTO gs_menu
    WHERE item_id = pv_item_id.
  IF sy-subrc <> 0.
    MESSAGE |Menu item { pv_item_id } does not exist.| TYPE 'E'.
  ENDIF.
  IF gs_menu-available <> abap_true.
    MESSAGE |Item { pv_item_id } ({ gs_menu-item_name }) is currently not available.| TYPE 'E'.
  ENDIF.

  lv_pos             = lv_pos + 1.
  gs_ordi-item_pos   = lv_pos.
  gs_ordi-item_id    = gs_menu-item_id.
  gs_ordi-quantity   = pv_qty.
  gs_ordi-unit_price = gs_menu-price.
  gs_ordi-waers      = gs_menu-waers.
  gs_ordi-item_total = gs_menu-price * pv_qty.
  APPEND gs_ordi TO gt_ordi.

  lv_total = lv_total + gs_ordi-item_total.
  lv_waers = gs_menu-waers.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form GET_OR_CREATE_CUSTOMER
*& Generates the next customer ID and inserts a new customer record.
*&---------------------------------------------------------------------*
FORM get_or_create_customer.
  DATA: lv_max_id TYPE yma_rest_cust-cust_id.

  SELECT MAX( cust_id ) FROM yma_rest_cust INTO lv_max_id.
  lv_cust_id = lv_max_id + 1.

  CLEAR gs_cust.
  gs_cust-cust_id   = lv_cust_id.
  gs_cust-cust_name = p_cname.
  gs_cust-phone     = p_phone.

  INSERT yma_rest_cust FROM gs_cust.
  IF sy-subrc <> 0.
    MESSAGE 'Error saving customer record.' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form CREATE_ORDER
*& Inserts the order header and all order line items into the database.
*&---------------------------------------------------------------------*
FORM create_order.
  DATA: lv_max_ord TYPE yma_rest_ord-order_id.

  SELECT MAX( order_id ) FROM yma_rest_ord INTO lv_max_ord.
  lv_order_id = lv_max_ord + 1.

  CLEAR gs_ord.
  gs_ord-order_id   = lv_order_id.
  gs_ord-cust_id    = lv_cust_id.
  gs_ord-table_no   = p_table.
  gs_ord-order_date = sy-datum.
  gs_ord-order_time = sy-uzeit.
  gs_ord-status     = 'O'.
  gs_ord-total_amt  = lv_total.
  gs_ord-waers      = lv_waers.
  gs_ord-created_by = sy-uname.

  INSERT yma_rest_ord FROM gs_ord.
  IF sy-subrc <> 0.
    MESSAGE 'Error saving order header.' TYPE 'E'.
  ENDIF.

  LOOP AT gt_ordi INTO gs_ordi.
    gs_ordi-order_id = lv_order_id.
    MODIFY gt_ordi FROM gs_ordi.
    INSERT yma_rest_ordi FROM gs_ordi.
    IF sy-subrc <> 0.
      MESSAGE |Error saving order item { gs_ordi-item_pos }.| TYPE 'E'.
    ENDIF.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_CONFIRMATION
*& Prints a formatted order receipt to the ABAP list.
*&---------------------------------------------------------------------*
FORM display_confirmation.
  ULINE.
  FORMAT COLOR COL_POSITIVE INTENSIFIED ON.
  WRITE: /1 'ORDER PLACED SUCCESSFULLY'.
  FORMAT COLOR OFF INTENSIFIED OFF.
  ULINE.
  WRITE: /1 'Order ID  :', lv_order_id.
  WRITE: /1 'Table No. :', p_table.
  WRITE: /1 'Customer  :', p_cname.
  IF p_phone IS NOT INITIAL.
    WRITE: /1 'Phone     :', p_phone.
  ENDIF.
  WRITE: /1 'Date/Time :', sy-datum, sy-uzeit.
  WRITE: /1 'Status    : Open'.
  ULINE.
  WRITE: /1 'Pos', 6 'Item-ID', 14 'Description', 47 'Qty',
          52 'Unit Price', 65 'Item Total', 78 'Curr'.
  ULINE.

  LOOP AT gt_ordi INTO gs_ordi.
    SELECT SINGLE item_name INTO gs_menu-item_name
      FROM yma_rest_menu
      WHERE item_id = gs_ordi-item_id.
    WRITE: /1  gs_ordi-item_pos,
            6  gs_ordi-item_id,
           14  gs_menu-item_name,
           47  gs_ordi-quantity,
           52  gs_ordi-unit_price CURRENCY gs_ordi-waers,
           65  gs_ordi-item_total CURRENCY gs_ordi-waers,
           78  gs_ordi-waers.
  ENDLOOP.

  ULINE.
  FORMAT COLOR COL_TOTAL INTENSIFIED ON.
  WRITE: /1 'TOTAL',
          65 lv_total CURRENCY lv_waers,
          78 lv_waers.
  FORMAT COLOR OFF INTENSIFIED OFF.
  ULINE.
ENDFORM.
