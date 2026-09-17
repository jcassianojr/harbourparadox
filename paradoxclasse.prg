#include "hbclass.ch"
#include "error.ch"
//===================================================================
// CLASSE GERENCIADORA DE CURSOR ESTILO DBF PARA PARADOX (ATUALIZADA)
//===================================================================
CLASS ParadoxCursor
   DATA cFile
   DATA pDoc
   DATA nTotalRecords
   DATA nFields
   DATA nRecNo        // 1 até nTotalRecords, ou nTotalRecords + 1 se EOF

   METHOD New( cFileName )
   METHOD Open()
   METHOD Close()
   METHOD GoTop()
   METHOD GoBottom()
   METHOD Skip( nRows )
   METHOD GoTo( nRec )
   METHOD Eof()
   METHOD Bof()
   METHOD RecNo()
   METHOD LastRec()
   METHOD pack()
   
   METHOD FieldName( nFieldPos )          // Retorna o nome do campo dado o número (1-based)
   METHOD FieldPos( cFieldName )          // Retorna o número do campo dado o nome
   METHOD FieldGet( nFieldPos )           // Retorna o valor do campo atual
   METHOD FieldPut( nFieldPos, xValue )     // Altera o valor de um campo no registro atual
   METHOD Append( aRowData )              // Adiciona um novo registro na tabela
   METHOD Delete()                        // Marca o registro atual como deletado
   METHOD DbStruct()
   METHOD Commit()
   
   METHOD Locate( bCondition )
   METHOD Seek( nFieldPos, xValorProcurado )
   METHOD ValidateData( nFieldPos, xValue )
   METHOD ThrowError( nErrorCode, cContext, cOperation )
   
   METHOD GetFields()
ENDCLASS

METHOD New( cFileName ) CLASS ParadoxCursor
   ::cFile := cFileName
   ::pDoc := NIL
   ::nTotalRecords := 0
   ::nFields := 0
   ::nRecNo := 0
RETURN Self

METHOD ValidateData( nFieldPos, xValue ) CLASS ParadoxCursor
   LOCAL aStruct := ::DbStruct()
   LOCAL cExpectedType, nExpectedLen, cValType

   IF nFieldPos < 1 .OR. nFieldPos > Len( aStruct )
      RETURN .F.
   ENDIF

   cExpectedType := aStruct[ nFieldPos ][ 2 ]
   nExpectedLen  := aStruct[ nFieldPos ][ 3 ]
   cValType      := ValType( xValue )

   DO CASE
      CASE cExpectedType == "C"
         IF cValType != "C"
            ::ThrowError( 1001, "Campo " + aStruct[nFieldPos][1] + " espera String", "ValidateData" )
         ENDIF
         IF Len( xValue ) > nExpectedLen
            // Trunca ou gera erro dependendo da sua regra de negócio
            ::ThrowError( 1002, "String excede tamanho do campo " + aStruct[nFieldPos][1], "ValidateData" )
         ENDIF

      CASE cExpectedType == "N" .OR. cExpectedType == "B"
         IF cValType != "N"
            ::ThrowError( 1003, "Campo " + aStruct[nFieldPos][1] + " espera Numerico", "ValidateData" )
         ENDIF

      CASE cExpectedType == "D"
         IF cValType != "D"
            ::ThrowError( 1004, "Campo " + aStruct[nFieldPos][1] + " espera Data", "ValidateData" )
         ENDIF

      CASE cExpectedType == "L"
         IF cValType != "L"
            ::ThrowError( 1005, "Campo " + aStruct[nFieldPos][1] + " espera Logico", "ValidateData" )
         ENDIF
   ENDCASE
RETURN .T.

METHOD ThrowError( nErrorCode, cContext, cOperation ) CLASS ParadoxCursor
   LOCAL oErr := ErrorNew()
   
   oErr:Severity    := 2 // ES_ERROR
   oErr:GenCode     := EG_DATATYPE
   oErr:SubSystem   := "PXLIB"
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
         oErr:Description := "Erro desconhecido da pxlib (" + hb_valtostr(nErrorCode) + ")"
   ENDCASE
   
   oErr:Args := { cContext }
   Eval( ErrorBlock(), oErr )
RETURN .F.

METHOD DbStruct() CLASS ParadoxCursor
   Local j, nFieldLen := 0, nFieldDec := 0, nFieldType := 0
   Local cFieldName := "", cHarbourType := "C"
   Local aStruct := {}

   IF ::pDoc == NIL .OR. ::nFields <= 0
      RETURN aStruct
   ENDIF

   FOR j := 0 TO ::nFields - 1
      cFieldName := PX_Get_Field_Name( ::pDoc, j )
      nFieldType := PX_Get_Field_Type_And_Len( ::pDoc, j, @nFieldLen, @nFieldDec )
      
       IF nFieldType == 1                                  // Alpha / String ($01)
         cHarbourType := "C" //HB_FT_STRING
         nFieldDec := 0
      ELSEIF nFieldType == 2 .OR. nFieldType == 21        // Date ($02) / Timestamp ($15)
         cHarbourType := "D" //HB_FT_DATE
         nFieldLen := 8
         nFieldDec := 0
      ELSEIF nFieldType == 3                              // Short integer ($03) - 2 bytes
         cHarbourType := "N" //HB_FT_LONG
         nFieldLen := 6
         nFieldDec := 0
      ELSEIF nFieldType == 4 .OR. nFieldType == 16        // Long integer ($04) / AutoInc ($16) - 4 bytes
         cHarbourType := "N" //HB_FT_LONG
         nFieldLen := 10
         nFieldDec := 0
      ELSEIF nFieldType == 5 .OR. nFieldType == 6 .OR. nFieldType == 17 // Currency ($05), Number ($06), BCD ($17) - 8 bytes+
         cHarbourType := "B" //HB_FT_DOUBLE
         nFieldLen := Max( nFieldLen, 18 )
      ELSEIF nFieldType == 9                              // Logical ($09) - 1 byte
         cHarbourType := "L" //HB_FT_LOGICAL
         nFieldLen := 1
         nFieldDec := 0
      ELSEIF nFieldType == 12 .OR. nFieldType == 13 .OR. nFieldType == 14 // Memos / BLOBs ($0C, $0D, $0E)
         cHarbourType := "M" //HB_FT_MEMO
         nFieldLen := 10
         nFieldDec := 0
      ELSE
         cHarbourType := "C"  //HB_FT_STRING
      ENDIF
      

      AAdd( aStruct, { cFieldName, cHarbourType, Max(1, nFieldLen), nFieldDec } )
   NEXT

RETURN aStruct


METHOD Open() CLASS ParadoxCursor
   ::pDoc := PX_New()
   IF ::pDoc == 0 .OR. ::pDoc == NIL
      RETURN .F.
   ENDIF

   IF PX_Open_File( ::pDoc, ::cFile ) == 0
      ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
      ::nFields := PX_Get_Num_Fields( ::pDoc )
      IF ::nTotalRecords > 0
         ::nRecNo := 1
      ELSE
         ::nRecNo := 0
      ENDIF
      RETURN .T.
   ENDIF

   PX_Delete( ::pDoc )
   ::pDoc := NIL
RETURN .F.

METHOD Close() CLASS ParadoxCursor
   IF ::pDoc != NIL
      PX_Close( ::pDoc )
      PX_Delete( ::pDoc )
      ::pDoc := NIL
   ENDIF
RETURN NIL

METHOD GoTop() CLASS ParadoxCursor
   IF ::nTotalRecords > 0
      ::nRecNo := 1
   ELSE
      ::nRecNo := 0
   ENDIF
RETURN NIL

METHOD GoBottom() CLASS ParadoxCursor
   IF ::nTotalRecords > 0
      ::nRecNo := ::nTotalRecords
   ELSE
      ::nRecNo := 0
   ENDIF
RETURN NIL

METHOD Skip( nRows ) CLASS ParadoxCursor
   IF ValType(nRows) != "N"
      nRows := 1
   ENDIF

   IF ::nTotalRecords == 0
      ::nRecNo := 0
      RETURN NIL
   ENDIF

   ::nRecNo += nRows

   IF ::nRecNo > ::nTotalRecords
      ::nRecNo := ::nTotalRecords + 1 // Estado de EOF garantido
   ELSEIF ::nRecNo < 1
      ::nRecNo := 0                   // Estado de BOF garantido
   ENDIF
RETURN NIL

METHOD GoTo( nRec ) CLASS ParadoxCursor
   IF nRec >= 1 .AND. nRec <= ::nTotalRecords
      ::nRecNo := nRec
   ENDIF
RETURN NIL

METHOD Eof() CLASS ParadoxCursor
   RETURN ( ::nRecNo > ::nTotalRecords )

METHOD Bof() CLASS ParadoxCursor
   RETURN ( ::nRecNo < 1 .AND. ::nTotalRecords > 0 )

METHOD RecNo() CLASS ParadoxCursor
   IF ::Eof()
      RETURN ::nTotalRecords + 1
   ENDIF
   IF ::Bof()
      RETURN 0
   ENDIF
RETURN ::nRecNo

METHOD LastRec() CLASS ParadoxCursor
   RETURN ::nTotalRecords

// --- IMPLEMENTAÇÃO DOS NOVOS MÉTODOS ---

METHOD FieldName( nFieldPos ) CLASS ParadoxCursor
   IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
      // A pxlib usa base 0 internamente
      RETURN PX_Get_Field_Name( ::pDoc, nFieldPos - 1 )
   ENDIF
RETURN ""

METHOD FieldPos( cFieldName ) CLASS ParadoxCursor
   Local j, cName
   cFieldName := Upper( AllTrim( cFieldName ) )
   FOR j := 1 TO ::nFields
      cName := Upper( AllTrim( ::FieldName( j ) ) )
      IF cName == cFieldName
         RETURN j
      ENDIF
   NEXT
RETURN 0 // Não encontrado

METHOD FieldGet( nFieldPos ) CLASS ParadoxCursor
   IF ::pDoc == NIL .OR. ::nRecNo < 1 .OR. ::nRecNo > ::nTotalRecords
      RETURN NIL
   ENDIF
   IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
      RETURN PX_Get_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1 )
   ENDIF
RETURN NIL

METHOD FieldPut( nFieldPos, xValue ) CLASS ParadoxCursor
   Local lOk := .F.

   IF ::nRecNo >= 1 .AND. ::nRecNo <= ::nTotalRecords
      IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
         // Bloqueia a execução se o dado não for compatível com a estrutura
         IF ::ValidateData( nFieldPos, xValue )
            // Atualiza o valor diretamente no documento Paradox
            lOk := ( PX_Put_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1, xValue ) == 0 )
         ENDIF
      ENDIF
   ENDIF

RETURN lOk

METHOD Commit() CLASS ParadoxCursor
   Local lOk := .F.
   IF ::pDoc != NIL
      // Força a persistência/gravação do buffer atual para o arquivo físico no disco
      lOk := ( PX_Flush( ::pDoc ) == 0 )
   ENDIF
RETURN lOk

METHOD Append( aRowData ) CLASS ParadoxCursor
   LOCAL nRet, i

   // 1. Valida todos os campos antes de enviar para o C
   FOR i := 1 TO Len( aRowData )
      ::ValidateData( i, aRowData[i] )
   NEXT

   // 2. Grava via pxlib
   nRet := PX_Append_Record( ::pDoc, aRowData )
   
   IF nRet == 0
      // 3. Atualiza estado e posiciona no novo registro
      ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
      ::nRecNo := ::nTotalRecords
      RETURN .T.
   ELSE
      ::ThrowError( nRet, "Falha na insercao de registro", "Append" )
   ENDIF
RETURN .F.

METHOD Delete() CLASS ParadoxCursor
   LOCAL nRet
   IF ::pDoc != NIL .AND. !::Eof() .AND. !::Bof()
      nRet := PX_Delete_Record( ::pDoc, ::nRecNo - 1 ) //
      
      IF nRet == 0
         ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
         
         // Se o cursor estava no ultimo registro e ele foi apagado, empurra para EOF
         IF ::nRecNo > ::nTotalRecords
            ::nRecNo := ::nTotalRecords + 1
         ENDIF
         RETURN .T.
      ELSE
         ::ThrowError( nRet, "Erro ao deletar RecNo " + hb_valtostr(::nRecNo), "Delete" )
      ENDIF
   ENDIF
RETURN .F.

METHOD GetFields() CLASS ParadoxCursor
   Local aNames := {}, j
   FOR j := 1 TO ::nFields
      AAdd( aNames, ::FieldName( j ) )
   NEXT
RETURN aNames

METHOD Locate( bCondition ) CLASS ParadoxCursor
   Local lFound := .F.
   Local nOrigem := ::nRecNo

   // Salva a posição atual e varre até o fim
   WHILE !::Eof()
      IF Eval( bCondition, Self )
         lFound := .T.
         EXIT
      ENDIF
      ::Skip( 1 )
   ENDDO

   IF !lFound
      // Se não achou, retorna o ponteiro para a origem
      ::GoTo( nOrigem )
   ENDIF

RETURN lFound


METHOD Seek( nCampoPos, xValorProcurado ) CLASS ParadoxCursor
   Local i, nTotal := ::LastRec()
   Local nOrigem := ::nRecNo

   FOR i := 1 TO nTotal
      ::GoTo( i )
      IF ::FieldGet( nCampoPos ) == xValorProcurado
         RETURN .T. // Encontrou e posicionou no registro
      ENDIF
   NEXT

   // Se não achar, restaura o ponteiro original
   ::GoTo( nOrigem )
RETURN .F.


METHOD Pack() CLASS ParadoxCursor
   Local cTempFile := ::cFile + ".tmp"
   Local pDocTemp := NIL
   Local nTotal := ::LastRec()
   Local aStruct := ::DbStruct() // Carrega a estrutura real mapeada em vez de forçar "C", 50
   Local i, j, nFields
   Local aRow := {}
   Local lOk := .F.

   IF ::nTotalRecords == 0
      RETURN .T.
   ENDIF

   nFields := ::nFields

   // Cria o documento temporário via pxlib
   pDocTemp := PX_New()
   IF pDocTemp == 0 .OR. pDocTemp == NIL
      RETURN .F.
   ENDIF

   // Tenta criar a tabela temporária usando a matriz exata de tipos
   IF PX_Create_Table( pDocTemp, cTempFile, aStruct ) == 0
      
      // Varre a tabela original copiando apenas os registros NÃO deletados
      FOR i := 1 TO nTotal
         ::GoTo( i )
         
         aRow := {}
         FOR j := 1 TO nFields
            AAdd( aRow, ::FieldGet( j ) )
         NEXT
         
         // Insere no temporário
         PX_Append_Record( pDocTemp, aRow )
      NEXT

      PX_Close( pDocTemp )
      PX_Delete( pDocTemp )
      lOk := .T.
   ENDIF

   IF lOk
      // Substitui o arquivo original pelo limpo
      ::Close()
      IF File( ::cFile )
         Erase( ::cFile )
      ENDIF
      FileCOPY( cTempFile, ::cFile )
      ::Open() // Reabre a tabela atualizada
      ? "PACK executado com sucesso! Registros deletados removidos."
   ENDIF

RETURN lOk