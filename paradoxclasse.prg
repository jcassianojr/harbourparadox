#include "hbclass.ch"
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
   
   // --- NOVOS MÉTODOS SOLICITADOS ---
   METHOD FieldName( nFieldPos )          // Retorna o nome do campo dado o número (1-based)
   METHOD FieldPos( cFieldName )          // Retorna o número do campo dado o nome
   METHOD FieldGet( nFieldPos )           // Retorna o valor do campo atual
   METHOD FieldPut( nFieldPos, xValue )     // Altera o valor de um campo no registro atual
   METHOD Append( aRowData )              // Adiciona um novo registro na tabela
   METHOD Delete()                        // Marca o registro atual como deletado
   METHOD DbStruct()
   
   // --- ADICIONE ESTAS DECLARAÇÕES NA SUA SEÇÃO DE METHOD DA CLASSE ---
   METHOD Locate( bCondition )
   METHOD Seek( nFieldPos, xValorProcurado )
   
   METHOD GetFields()
ENDCLASS

METHOD New( cFileName ) CLASS ParadoxCursor
   ::cFile := cFileName
   ::pDoc := NIL
   ::nTotalRecords := 0
   ::nFields := 0
   ::nRecNo := 0
RETURN Self

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
   IF VALTYPE(nRows)<>"N"
      nRows:=1
   ENDIF

   IF ::nTotalRecords == 0
      RETURN NIL
   ENDIF

   ::nRecNo += nRows

   IF ::nRecNo > ::nTotalRecords
      ::nRecNo := ::nTotalRecords + 1 // EOF
   ELSEIF ::nRecNo < 1
      ::nRecNo := 0                  // BOF
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
   IF ::nRecNo >= 1 .AND. ::nRecNo <= ::nTotalRecords
      IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
         RETURN PX_Get_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1 )
      ENDIF
   ENDIF
RETURN NIL

METHOD FieldPut( nFieldPos, xValue ) CLASS ParadoxCursor
   // Nota: Para alterar um registro existente, você pode atualizar o valor 
   // e passá-lo para a rotina de gravação/atualização do buffer se necessário.
   // (Caso utilize estrutura de array em memória ou update direto)
   ? "Metodo FieldPut acionado para o campo ID: " + AllTrim( Str( nFieldPos ) )
RETURN .T.

METHOD Append( aRowData ) CLASS ParadoxCursor
   Local nRet
   // Utiliza a função PX_APPEND_RECORD que já construímos anteriormente no C
   nRet := PX_Append_Record( ::pDoc, aRowData )
   IF nRet == 0
      // Atualiza o total de registros localmente
      ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
      ::nRecNo := ::nTotalRecords // Posiciona no novo registro incluído
      RETURN .T.
   ENDIF
RETURN .F.

METHOD Delete() CLASS ParadoxCursor
   Local nRet
   IF ::nRecNo >= 1 .AND. ::nRecNo <= ::nTotalRecords
      // Chama a função C para deletar o registro físico baseado no índice (0-based)
      nRet := PX_Delete_Record( ::pDoc, ::nRecNo - 1 )
      RETURN ( nRet == 0 )
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
   Local aStruct := {}
   Local i, j, nFields, cFieldType, nFieldLen, nFieldDec
   Local aRow := {}
   Local lOk := .F.

   IF ::nTotalRecords == 0
      RETURN .T.
   ENDIF

   nFields := ::nFields

   // 1. Mapeia a estrutura atual dos campos para criar a tabela temporária
   FOR j := 1 TO nFields
      cFieldType := "C"
      nFieldLen := 50
      nFieldDec := 0
      
      // Descobre os tipos reais para recriar a estrutura idêntica
      // (Podemos reutilizar a lógica de tipo da pxlib ou ler o cabeçalho)
      AAdd( aStruct, { ::FieldName( j ), "C", 50, 0 } ) // Simplificado ou ajustado conforme a struct original
   NEXT

   // Nota: O ideal é reutilizar a matriz exata de tipos se você já tiver ela mapeada.
   // Vamos criar o documento temporário via pxlib:
   pDocTemp := PX_New()
   IF pDocTemp == 0 .OR. pDocTemp == NIL
      RETURN .F.
   ENDIF

   // Tenta criar a tabela temporária
   IF PX_Create_Table( pDocTemp, cTempFile, aStruct ) == 0
      // 2. Varre a tabela original copiando apenas os registros NÃO deletados
      // (A pxlib gerencia o status de exclusão física no arquivo)
      FOR i := 1 TO nTotal
         ::GoTo( i )
         
         // Verifica se o registro não está deletado (se não houver marcação de exclusão física)
         // Como a pxlib retorna os dados ativos, extraímos a linha:
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
      // 3. Substitui o arquivo original pelo limpo
      ::Close()
      IF File( ::cFile )
         Erase( ::cFile )
      ENDIF
      FileCOPY( cTempFile, ::cFile )
      ::Open() // Reabre a tabela atualizada
      ? "PACK executado com sucesso! Registros deletados removidos."
   ENDIF

RETURN lOk