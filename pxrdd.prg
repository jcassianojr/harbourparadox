#include "rddsys.ch"
#include "usrrdd.ch"
#include "fileio.ch"
#include "error.ch"
#include "dbstruct.ch"
#include "dbinfo.ch"

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
   aMyFunc[ UR_RECCOUNT ]   := ( @PX_RECCOUNT() ) 
   // Mapeia informações globais do RDD (hb_rddInfo)
   aMyFunc[ UR_RDDINFO ] := ( @PX_RDDINFO() )
   // Mapeia informações específicas da tabela/área aberta (DbInfo)
   aMyFunc[ UR_INFO ]    := ( @PX_INFO() )
   
 //  aMyFunc[ UR_GETSTRUCT ] := ( @PX_DBSTRUCT() ) 

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
   
   IF pPxDoc == NIL //.OR. pPxDoc == 0
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
      
    IF nFieldType == 1                                  // Alpha / String ($01)
         cHarbourType := HB_FT_STRING
         nFieldDec := 0
      ELSEIF nFieldType == 2 .OR. nFieldType == 21        // Date ($02) / Timestamp ($15)
         cHarbourType := HB_FT_DATE
         nFieldLen := 8
         nFieldDec := 0
      ELSEIF nFieldType == 3                              // Short integer ($03) - 2 bytes
         cHarbourType := HB_FT_LONG
         nFieldLen := 6
         nFieldDec := 0
      ELSEIF nFieldType == 4 .OR. nFieldType == 16        // Long integer ($04) / AutoInc ($16) - 4 bytes
         cHarbourType := HB_FT_LONG
         nFieldLen := 10
         nFieldDec := 0
      ELSEIF nFieldType == 5 .OR. nFieldType == 6 .OR. nFieldType == 17 // Currency ($05), Number ($06), BCD ($17) - 8 bytes+
         cHarbourType := HB_FT_DOUBLE
         nFieldLen := Max( nFieldLen, 18 )
      ELSEIF nFieldType == 9                              // Logical ($09) - 1 byte
         cHarbourType := HB_FT_LOGICAL
         nFieldLen := 1
         nFieldDec := 0
      ELSEIF nFieldType == 12 .OR. nFieldType == 13 .OR. nFieldType == 14 // Memos / BLOBs ($0C, $0D, $0E)
         cHarbourType := HB_FT_MEMO
         nFieldLen := 10
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
         // Nota: Garantir que PX_Delete e PX_Delete2 são consistentes com a sua pxlib
         PX_Delete( aWAData[ PX_AREA_DOC ] ) 
      ENDIF
      
      // LIMPEZA DO ESTADO FANTASMA
      aWAData[ PX_AREA_DOC ]    := NIL
      aWAData[ PX_AREA_RECNO ]  := 0
      aWAData[ PX_AREA_TOTAL ]  := 0
      aWAData[ PX_AREA_BOF ]    := .T.
      aWAData[ PX_AREA_EOF ]    := .T.
      aWAData[ PX_AREA_ROWBUF ] := NIL
      aWAData[ PX_AREA_APPEND ] := .F.
   ENDIF
   
RETURN UR_SUPER_CLOSE( nWA )

STATIC FUNCTION PX_GETVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   // VALIDAÇÃO DE SEGURANÇA
   IF aWAData == NIL .OR. aWAData[ PX_AREA_DOC ] == NIL
      xValue := NIL
      RETURN FAILURE
   ENDIF

   IF aWAData[ PX_AREA_APPEND ] .AND. !Empty( aWAData[ PX_AREA_ROWBUF ] )
      xValue := aWAData[ PX_AREA_ROWBUF ][ nField ]
   ELSEIF !aWAData[ PX_AREA_EOF ]
      xValue := PX_Get_Field_Val( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_RECNO ] - 1, nField - 1 )
   ELSE
      xValue := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_PUTVALUE( nWA, nField, xValue )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   IF aWAData == NIL .OR. aWAData[ PX_AREA_DOC ] == NIL
      RETURN FAILURE
   ENDIF
   
   IF aWAData[ PX_AREA_ROWBUF ] == NIL
      aWAData[ PX_AREA_ROWBUF ] := Array( PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] ) )
   ENDIF
   
   // BLOQUEIA A GRAVAÇÃO E SINALIZA ERRO AO MOTOR
   IF !PX_VALIDATEDATA( nWA, nField, xValue )
      RETURN FAILURE
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
   LOCAL nRet, nFields
   
   IF aWAData == NIL .OR. aWAData[ PX_AREA_DOC ] == NIL
      RETURN FAILURE
   ENDIF
   
   IF aWAData[ PX_AREA_APPEND ] .AND. !Empty( aWAData[ PX_AREA_ROWBUF ] )
      
      // SANITY CHECK: Garante integridade do array antes do C
      nFields := PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] )
      IF Len( aWAData[ PX_AREA_ROWBUF ] ) != nFields
         PX_THROWERROR( nWA, 1006, "Buffer de inserção incompatível com estrutura", "PX_FLUSH" )
         RETURN FAILURE
      ENDIF

      nRet := PX_Append_Record( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_ROWBUF ] )
      
      IF nRet == 0
         aWAData[ PX_AREA_TOTAL ] := PX_Get_Num_Records( aWAData[ PX_AREA_DOC ] )
         aWAData[ PX_AREA_RECNO ] := aWAData[ PX_AREA_TOTAL ]
      ELSE
         PX_THROWERROR( nWA, nRet, "Falha na inserção de registro", "PX_FLUSH" )
      ENDIF
      
      aWAData[ PX_AREA_APPEND ] := .F.
      aWAData[ PX_AREA_ROWBUF ] := NIL
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_DELETE( nWA )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL nRet
   
   // FALTA ESTA VALIDAÇÃO:
   IF aWAData == NIL .OR. aWAData[ PX_AREA_DOC ] == NIL
      RETURN FAILURE
   ENDIF
   
   IF !aWAData[ PX_AREA_EOF ] .AND. !aWAData[ PX_AREA_BOF ]
      nRet := PX_Delete_Record( aWAData[ PX_AREA_DOC ], aWAData[ PX_AREA_RECNO ] - 1 )
      
      IF nRet == 0
         aWAData[ PX_AREA_TOTAL ] := PX_Get_Num_Records( aWAData[ PX_AREA_DOC ] )
         
         // Se o registro deletado era o ultimo, posiciona em EOF
         IF aWAData[ PX_AREA_RECNO ] > aWAData[ PX_AREA_TOTAL ]
            aWAData[ PX_AREA_RECNO ] := aWAData[ PX_AREA_TOTAL ] + 1
            aWAData[ PX_AREA_EOF ]   := .T.
         ENDIF
      ELSE
         PX_THROWERROR( nWA, nRet, "Erro ao deletar RecNo " + hb_valtostr(aWAData[ PX_AREA_RECNO ]), "PX_DELETE" )
      ENDIF
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_FCOUNT( nWA, nFields )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   // VALIDAÇÃO SEGURA:
   IF aWAData != NIL .AND. aWAData[ PX_AREA_DOC ] != NIL
      nFields := PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] )
   ELSE
      nFields := 0
   ENDIF
RETURN SUCCESS

STATIC FUNCTION PX_RECCOUNT( nWA, nRecords )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   
   // VALIDAÇÃO SEGURA:
   IF aWAData != NIL
      nRecords := aWAData[ PX_AREA_TOTAL ]
   ELSE
      nRecords := 0
   ENDIF
RETURN SUCCESS

/* A RDD gera a struct com base na field da open
STATIC FUNCTION PX_DBSTRUCT( nWA, aStruct )
   LOCAL aWAData := USRRDD_AREADATA( nWA )
   LOCAL nFields, j, cFieldName, nFieldLen := 0, nFieldDec := 0, nFieldType := 0
   LOCAL cStructType

   IF aWAData[ PX_AREA_DOC ] == NIL
      aStruct := {}
      RETURN SUCCESS
   ENDIF

   nFields := PX_Get_Num_Fields( aWAData[ PX_AREA_DOC ] )
   aStruct := Array( nFields, 4 )

   FOR j := 0 TO nFields - 1
      cFieldName := PX_Get_Field_Name( aWAData[ PX_AREA_DOC ], j )
      nFieldType := PX_Get_Field_Type_And_Len( aWAData[ PX_AREA_DOC ], j, @nFieldLen, @nFieldDec )

      IF nFieldType == 1                                  // Alpha -> Char ("C")
         cStructType := "C"
         nFieldDec   := 0
      ELSEIF nFieldType == 2 .OR. nFieldType == 21        // Date / Timestamp -> Date ("D")
         cStructType := "D"
         nFieldLen   := 8
         nFieldDec   := 0
      ELSEIF nFieldType == 3                              // Short integer -> Numeric ("N")
         cStructType := "N"
         nFieldLen   := 6
         nFieldDec   := 0
      ELSEIF nFieldType == 4 .OR. nFieldType == 16        // Long integer / AutoInc -> Numeric ("N")
         cStructType := "N"
         nFieldLen   := 10
         nFieldDec   := 0
      ELSEIF nFieldType == 5 .OR. nFieldType == 6 .OR. nFieldType == 17 // Currency / Number / BCD -> Numeric ("N") ou Double ("B")
         cStructType := "N" // Altere para "B" se quiser manter o tipo Double nativo do Harbour
         nFieldLen   := Max( nFieldLen, 18 )
      ELSEIF nFieldType == 9                              // Logical -> Logical ("L")
         cStructType := "L"
         nFieldLen   := 1
         nFieldDec   := 0
      ELSEIF nFieldType == 12 .OR. nFieldType == 13 .OR. nFieldType == 14 // Memos -> Memo ("M")
         cStructType := "M"
         nFieldLen   := 10
         nFieldDec   := 0
      ELSE
         cStructType := "C"
      ENDIF

      aStruct[ j + 1, DBS_NAME ] := cFieldName
      aStruct[ j + 1, DBS_TYPE ] := cStructType
      aStruct[ j + 1, DBS_LEN  ] := Max( 1, nFieldLen )
      aStruct[ j + 1, DBS_DEC  ] := nFieldDec
   NEXT

RETURN SUCCESS
*/

// Dentro do handler de métodos do seu RDD (ex: PX_RDDPROCS ou equivalente)
STATIC FUNCTION PX_RDDINFO( nIndex, cargo )
   Local xRet := NIL
   HB_SYMBOL_UNUSED( cargo ) 

   DO CASE
      CASE nIndex == RDDI_TABLEEXT
         xRet := ".db" // Extensão padrão das tabelas Paradox

      CASE nIndex == RDDI_MEMOEXT
         xRet := ".mb" // Extensão padrão de arquivos memo do Paradox (se houver)

      CASE nIndex == RDDI_ORDBAGEXT
         xRet := ".px" // Extensão padrão de índices do Paradox (ou .val / .xlg)
   ENDCASE

RETURN xRet

STATIC FUNCTION PX_INFO( nWA, nItem, xArg )
   LOCAL xRet := NIL

   DO CASE
      CASE nItem == DBI_ISDBF
         xRet := .F.  // Indica que não é um DBF tradicional, mas sim Paradox

      CASE nItem == DBI_CANPUTREC
         xRet := .T.  // Indica que o RDD suporta inserção de registros

      // Caso não seja um item tratado, repassa para o comportamento padrão do USRRDD
      OTHERWISE
         xRet := UR_SUPER_INFO( nWA, nItem, xArg )
   ENDCASE

RETURN xRet

STATIC FUNCTION PX_THROWERROR( nWA, nErrorCode, cContext, cOperation )
   LOCAL oErr := ErrorNew()

   oErr:Severity    := 2 // ES_ERROR
   oErr:GenCode     := EG_DATATYPE
   oErr:SubSystem   := "PXRDD"
   oErr:SubCode     := nErrorCode
   oErr:Operation   := cOperation

   DO CASE
      CASE nErrorCode == -1
         oErr:Description := "Parametros invalidos ou ponteiro PX_DOC nulo."
      CASE nErrorCode == -2
         oErr:Description := "Falha de alocacao de memoria no buffer interno."
      CASE nErrorCode == -3
         oErr:Description := "Erro interno da pxlib ao tentar persistir (put/append)."
      OTHERWISE
         oErr:Description := "Erro da pxlib (" + hb_valtostr(nErrorCode) + ")"
   ENDCASE

   oErr:Args := { cContext }
   UR_SUPER_ERROR( nWA, oErr )
RETURN .F.

STATIC FUNCTION PX_VALIDATEDATA( nWA, nField, xValue )
   LOCAL cExpectedType, nExpectedLen
   LOCAL cValType := ValType( xValue )
   LOCAL cFieldName

   // Extrai os metadados do campo diretamente do USRRDD
   UR_SUPER_FIELDINFO( nWA, nField, DBS_TYPE, @cExpectedType )
   UR_SUPER_FIELDINFO( nWA, nField, DBS_LEN,  @nExpectedLen )
   UR_SUPER_FIELDINFO( nWA, nField, DBS_NAME, @cFieldName )

   DO CASE
      CASE cExpectedType == "C"
         IF cValType != "C"
            PX_THROWERROR( nWA, 1001, "Campo " + cFieldName + " espera String", "PX_VALIDATEDATA" )
            RETURN .F.
         ENDIF
         IF Len( xValue ) > nExpectedLen
            PX_THROWERROR( nWA, 1002, "String excede tamanho do campo " + cFieldName, "PX_VALIDATEDATA" )
            RETURN .F.
         ENDIF

      CASE cExpectedType == "N" .OR. cExpectedType == "B"
         IF cValType != "N"
            PX_THROWERROR( nWA, 1003, "Campo " + cFieldName + " espera Numerico", "PX_VALIDATEDATA" )
            RETURN .F.
         ENDIF

      CASE cExpectedType == "D"
         IF cValType != "D"
            PX_THROWERROR( nWA, 1004, "Campo " + cFieldName + " espera Data", "PX_VALIDATEDATA" )
            RETURN .F.
         ENDIF

      CASE cExpectedType == "L"
         IF cValType != "L"
            PX_THROWERROR( nWA, 1005, "Campo " + cFieldName + " espera Logico", "PX_VALIDATEDATA" )
            RETURN .F.
         ENDIF
   ENDCASE
RETURN .T.