#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"

#define PX_AREA_DOC      1  // Ponteiro da pxlib (pPxDoc)
#define PX_AREA_RECNO    2  // Numero do registro atual (1-based)
#define PX_AREA_TOTAL    3  // Total de registros
#define PX_AREA_BOF      4  // Flag de Inicio do Arquivo
#define PX_AREA_EOF      5  // Flag de Fim de Arquivo
#define PX_AREA_ROWBUF   6  // Buffer da linha (para edicao/append)
#define PX_AREA_APPEND   7  // Flag indicando modo Append
#define PX_AREA_LEN      7

ANNOUNCE PXRDD

// +--------------------------------------------------------------------
// +    Inicializa e Registra a RDD "PXRDD" no Motor do Harbour
// +--------------------------------------------------------------------
INIT PROCEDURE PXRDD_INIT()
   rddRegister( "PXRDD", RDT_FULL )
RETURN

// +--------------------------------------------------------------------
// +    Tabela de Roteamento (Mapeia as chamadas do Harbour)
// +--------------------------------------------------------------------
FUNCTION PXRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID )
   LOCAL cSuperRDD := NIL
   LOCAL aMyFunc[ UR_METHODCOUNT ]

   aMyFunc[ UR_INIT ]     := ( @PX_INIT() )
   aMyFunc[ UR_NEW ]      := ( @PX_NEWRDD() )
   aMyFunc[ UR_OPEN ]     := ( @PX_OPEN() )
   aMyFunc[ UR_CLOSE ]    := ( @PX_CLOSERDD() )
   aMyFunc[ UR_GETVALUE ] := ( @PX_GETVALUE() )
   aMyFunc[ UR_PUTVALUE ] := ( @PX_PUTVALUE() )
   aMyFunc[ UR_SKIP ]     := ( @PX_SKIP() )
   aMyFunc[ UR_GOTO ]     := ( @PX_GOTO() )
   aMyFunc[ UR_GOTOID ]   := ( @PX_GOTOID() )
   aMyFunc[ UR_GOTOP ]    := ( @PX_GOTOP() )
   aMyFunc[ UR_GOBOTTOM ] := ( @PX_GOBOTTOM() )
   aMyFunc[ UR_RECID ]    := ( @PX_RECID() )
   aMyFunc[ UR_BOF ]      := ( @PX_BOF() )
   aMyFunc[ UR_EOF ]      := ( @PX_EOF() )
   aMyFunc[ UR_APPEND ]   := ( @PX_APPEND() )
   aMyFunc[ UR_FLUSH ]    := ( @PX_FLUSH() )
   aMyFunc[ UR_DELETE ]   := ( @PX_DELETE() )
   aMyFunc[ UR_FIELDCOUNT ]   := ( @PX_FCOUNT() )
   aMyFunc[ UR_RECCOUNT ]   := ( @PX_RECCOUNT() )  // <-- Adicionado aqui para o LastRec()

   RETURN USRRDD_GETFUNCTABLE( pFuncCount, pFuncTable, pSuperTable, nRddID, cSuperRDD, aMyFunc )

// +--------------------------------------------------------------------
// +    Metodos Internos da RDD
// +--------------------------------------------------------------------
STATIC FUNCTION PX_INIT( nRDD )
   USRRDD_RDDDATA( nRDD )
RETURN SUCCESS

STATIC FUNCTION PX_NEWRDD( nWA )
   LOCAL aData := Array( PX_AREA_LEN )
   aData[ PX_AREA_DOC ]   := NIL
   aData[ PX_AREA_RECNO ] := 0
   aData[ PX_AREA_TOTAL ] := 0
   aData[ PX_AREA_BOF ]   := .T.
   aData[ PX_AREA_EOF ]   := .T.
   aData[ PX_AREA_ROWBUF ]:= NIL
   aData[ PX_AREA_APPEND ]:= .F.
   USRRDD_AREADATA( nWA, aData )
RETURN SUCCESS

STATIC FUNCTION PX_OPEN( nWA, aOpenInfo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL pPxDoc, nFields, j, aField
   LOCAL nFieldLen := 0, nFieldDec := 0, nFieldType := 0
   LOCAL oError, nResult, cHarbourType, cFileName, cFieldName

   cFileName := AllTrim( aOpenInfo[ UR_OI_NAME ] )

   // Garante a chamada explícita do construtor C da pxlib
   pPxDoc := PX_New()
   
   IF pPxDoc == NIL .OR. pPxDoc == 0
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:SubCode     := 1000
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Falha crítica: ponteiro PX_New() retornou nulo."
      oError:FileName    := cFileName
      oError:CanDefault  := .T.
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   aWAData[ PX_AREA_DOC ] := pPxDoc

   // Abre o arquivo físico validando o ponteiro alocado
   IF PX_Open_File( pPxDoc, cFileName ) != 0
      PX_Delete( pPxDoc )
      aWAData[ PX_AREA_DOC ] := NIL
      oError := ErrorNew()
      oError:GenCode     := EG_OPEN
      oError:SubCode     := 1000
      oError:Description := hb_langErrMsg( EG_OPEN ) + ", Nao foi possivel abrir o arquivo Paradox."
      oError:FileName    := cFileName
      oError:CanDefault  := .T.
      UR_SUPER_ERROR( nWA, oError )
      RETURN FAILURE
   ENDIF

   // Popula os metadados da WorkArea
   aWAData[ PX_AREA_TOTAL ] := PX_Get_Num_Records( pPxDoc )
   aWAData[ PX_AREA_RECNO ] := If( aWAData[ PX_AREA_TOTAL ] > 0, 1, 0 )
   aWAData[ PX_AREA_BOF ]   := ( aWAData[ PX_AREA_TOTAL ] == 0 )
   aWAData[ PX_AREA_EOF ]   := ( aWAData[ PX_AREA_TOTAL ] == 0 )
   aWAData[ PX_AREA_APPEND ]:= .F.

   nFields := PX_Get_Num_Fields( pPxDoc )
   UR_SUPER_SETFIELDEXTENT( nWA, nFields )

   FOR j := 0 TO nFields - 1
      cFieldName := PX_Get_Field_Name( pPxDoc, j )
      nFieldType := PX_Get_Field_Type_And_Len( pPxDoc, j, @nFieldLen, @nFieldDec )
      
      IF nFieldType == 1
         cHarbourType := HB_FT_STRING
         nFieldDec := 0
      ELSEIF nFieldType == 2 .OR. nFieldType == 21
         cHarbourType := HB_FT_DATE
         nFieldLen := 8
         nFieldDec := 0
      ELSEIF nFieldType >= 3 .AND. nFieldType <= 4 .OR. nFieldType == 22
         cHarbourType := HB_FT_INTEGER
         nFieldDec := 0
      ELSEIF nFieldType == 5 .OR. nFieldType == 6
         cHarbourType := HB_FT_DOUBLE
         nFieldLen := Max( nFieldLen, 18 )
      ELSEIF nFieldType == 9
         cHarbourType := HB_FT_LOGICAL
         nFieldLen := 1
         nFieldDec := 0
      ELSE
         cHarbourType := HB_FT_STRING
      ENDIF

      aField                  := Array( UR_FI_SIZE )
      aField[ UR_FI_NAME ]    := cFieldName
      aField[ UR_FI_TYPE ]    := cHarbourType
      aField[ UR_FI_TYPEEXT ] := 0
      aField[ UR_FI_LEN ]     := Max( 1, nFieldLen )
      aField[ UR_FI_DEC ]     := nFieldDec
      
      UR_SUPER_ADDFIELD( nWA, aField )
   NEXT

   nResult := UR_SUPER_OPEN( nWA, aOpenInfo )
RETURN nResult


STATIC FUNCTION PX_CLOSERDD( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF aWAData != NIL .AND. HB_IsArray( aWAData ) .AND. Len( aWAData ) >= PX_AREA_DOC
      IF aWAData[ PX_AREA_DOC ] != NIL
         PX_Close( aWAData[ PX_AREA_DOC ] )
         PX_Delete2( aWAData[ PX_AREA_DOC ] )
         aWAData[ PX_AREA_DOC ] := NIL
      ENDIF
   ENDIF
   
RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION PX_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ PX_AREA_APPEND ] .AND. !Empty( aWAData[ PX_AREA_ROWBUF ] )
      xValue := aWAData[ PX_AREA_ROWBUF ][ nField ]
   ELSEIF !aWAData[ PX_AREA_EOF ]
      // RecNo e Field na pxlib iniciam em 0
      xValue := PX_Get_Field_Val( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_RECNO ] - 1, nField - 1 )
   ELSE
      xValue := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ PX_AREA_ROWBUF ] == NIL
      // Inicializa o buffer com o total de campos se nao existir
      aWAData[ PX_AREA_ROWBUF ] := Array( PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] ) )
   ENDIF
   aWAData[ PX_AREA_ROWBUF ][ nField ] := xValue
RETURN SUCCESS

STATIC FUNCTION PX_SKIP( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL nNewRec := aWAData[ PX_AREA_RECNO ] + nRecords

   IF aWAData[ PX_AREA_TOTAL ] == 0
      aWAData[ PX_AREA_BOF ] := .T.
      aWAData[ PX_AREA_EOF ] := .T.
      RETURN SUCCESS
   ENDIF

   IF nNewRec > aWAData[ PX_AREA_TOTAL ]
      aWAData[ PX_AREA_RECNO ] := aWAData[ PX_AREA_TOTAL ] + 1
      aWAData[ PX_AREA_EOF ]   := .T.
      aWAData[ PX_AREA_BOF ]   := .F.
   ELSEIF nNewRec < 1
      aWAData[ PX_AREA_RECNO ] := 1
      aWAData[ PX_AREA_BOF ]   := .T.
      aWAData[ PX_AREA_EOF ]   := .F.
   ELSE
      aWAData[ PX_AREA_RECNO ] := nNewRec
      aWAData[ PX_AREA_BOF ]   := .F.
      aWAData[ PX_AREA_EOF ]   := .F.
   ENDIF
   aWAData[ PX_AREA_APPEND ] := .F.
RETURN SUCCESS

STATIC FUNCTION PX_GOTOP( nWA )
   RETURN PX_GOTO( nWA, 1 )

STATIC FUNCTION PX_GOBOTTOM( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   RETURN PX_GOTO( nWA, aWAData[ PX_AREA_TOTAL ] )

STATIC FUNCTION PX_GOTOID( nWA, nRecord )
   RETURN PX_GOTO( nWA, nRecord )

STATIC FUNCTION PX_GOTO( nWA, nRecord )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ PX_AREA_TOTAL ] == 0
      aWAData[ PX_AREA_BOF ] := .T.
      aWAData[ PX_AREA_EOF ] := .T.
      aWAData[ PX_AREA_RECNO ] := 1
      RETURN SUCCESS
   ENDIF

   IF nRecord >= 1 .AND. nRecord <= aWAData[ PX_AREA_TOTAL ]
      aWAData[ PX_AREA_RECNO ] := nRecord
      aWAData[ PX_AREA_BOF ] := .F.
      aWAData[ PX_AREA_EOF ] := .F.
   ENDIF
   aWAData[ PX_AREA_APPEND ] := .F.
RETURN SUCCESS

STATIC FUNCTION PX_BOF( nWA, lBof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lBof := aWAData[ PX_AREA_BOF ]
RETURN SUCCESS

STATIC FUNCTION PX_EOF( nWA, lEof )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   lEof := aWAData[ PX_AREA_EOF ]
RETURN SUCCESS

STATIC FUNCTION PX_RECID( nWA, nRecNo )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecno := aWAData[ PX_AREA_RECNO ]
RETURN SUCCESS

STATIC FUNCTION PX_APPEND( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   HB_SYMBOL_UNUSED( nRecords )
   aWAData[ PX_AREA_ROWBUF ] := Array( PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] ) )
   aWAData[ PX_AREA_APPEND ] := .T.
   aWAData[ PX_AREA_EOF ]    := .T.
RETURN SUCCESS

STATIC FUNCTION PX_FLUSH( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ PX_AREA_APPEND ] .AND. !Empty( aWAData[ PX_AREA_ROWBUF ] )
      IF PX_Append_Record( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_ROWBUF ] ) == 0
         aWAData[ PX_AREA_TOTAL ] := PX_Get_Num_Records( aWAData[ PX_AREA_DOC ] )
         aWAData[ PX_AREA_RECNO ] := aWAData[ PX_AREA_TOTAL ]
      ENDIF
      aWAData[ PX_AREA_APPEND ] := .F.
      aWAData[ PX_AREA_ROWBUF ] := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF !aWAData[ PX_AREA_EOF ]
      PX_Delete_Record( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_RECNO ] - 1 )
      aWAData[ PX_AREA_TOTAL ] := PX_Get_Num_Records( aWAData[ PX_AREA_DOC ] )
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_FCOUNT( nWA, nFields )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   IF aWAData[ PX_AREA_DOC ] != NIL
      nFields := PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] )
   ELSE
      nFields := 0
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   nRecords := aWAData[ PX_AREA_TOTAL ]
RETURN SUCCESS