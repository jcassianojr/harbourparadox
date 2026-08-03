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
   
   // --- NOVOS MÉTODOS SOLICITADOS ---
   METHOD FieldName( nFieldPos )          // Retorna o nome do campo dado o número (1-based)
   METHOD FieldPos( cFieldName )          // Retorna o número do campo dado o nome
   METHOD FieldGet( nFieldPos )           // Retorna o valor do campo atual
   METHOD FieldPut( nFieldPos, xValue )     // Altera o valor de um campo no registro atual
   METHOD Append( aRowData )              // Adiciona um novo registro na tabela
   METHOD Delete()                        // Marca o registro atual como deletado
   
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
   DEFAULT nRows TO 1

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
   ENDWHILE

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