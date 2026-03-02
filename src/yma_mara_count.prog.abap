*&---------------------------------------------------------------------*
*& Report YMA_MARA_COUNT
*&---------------------------------------------------------------------*
*& Counts the number of materials in the SAP system (table MARA)
*& and displays the result on screen.
*&---------------------------------------------------------------------*
REPORT yma_mara_count.

DATA: lv_count TYPE i.

SELECT COUNT(*) INTO lv_count FROM mara.

WRITE: / 'Number of materials in the system:', lv_count.
