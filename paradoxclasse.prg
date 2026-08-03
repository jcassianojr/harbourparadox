#include "hbclass.ch"

/*
PROCEDURE Main( cDbFile )
   Local oParadox
   
   DEFAULT cDbFile TO "tabela_gerada.db"

   IF !File( cDbFile )
      ? "Arquivo nao encontrado: " + cDbFile
      RETURN
   ENDIF

   // Instancia o nosso navegador estilo DBF para Paradox
   oParadox := ParadoxCursor():New( cDbFile )
   
   IF oParadox:Open()
      ? "Tabela aberta com sucesso! Total de registros:", oParadox:LastRec()
      ? "--------------------------------------------------"

      // 1. GO TOP
      oParadox:GoTop()
      ? "GO TOP -> RecNo():", oParadox:RecNo(), "| EOF:", oParadox:Eof(), "| BOF:", oParadox:Bof()
      ExibirRegistroAtual( oParadox )

      // 2. SKIP +2 (Avança 2 registros)
      ? "Executando SKIP 2..."
      oParadox:Skip( 2 )
      ? "RecNo():", oParadox:RecNo()
      ExibirRegistroAtual( oParadox )

      // 3. SKIP -1 (Recua 1 registro)
      ? "Executando SKIP -1..."
      oParadox:Skip( -1 )
      ? "RecNo():", oParadox:RecNo()
      ExibirRegistroAtual( oParadox )

      // 4. GO TO (Vai direto para o registro 2)
      ? "Executando DBGOTO(2)..."
      oParadox:GoTo( 2 )
      ExibirRegistroAtual( oParadox )

      // 5. GO BOTTOM
      oParadox:GoBottom()
      ? "GO BOTTOM -> RecNo():", oParadox:RecNo()
      ExibirRegistroAtual( oParadox )

      // 6. Testando EOF (Skip adiante do último)
      ? "Executando SKIP 1 apos o ultimo (Testando EOF)..."
      oParadox:Skip( 1 )
      ? "RecNo():", oParadox:RecNo(), "| EOF:", oParadox:Eof()

      oParadox:Close()
   ELSE
      ? "Erro ao abrir a tabela Paradox."
   ENDIF

RETURN


// Função auxiliar apenas para demonstrar a leitura do registro posicionado atual
STATIC PROCEDURE ExibirRegistroAtual( oParadox )
   Local aCampos := oParadox:GetFields()
   Local cTexto := ""
   Local j
   
   FOR j := 1 TO Len( aCampos )
      cTexto += aCampos[j] + ": " + cValToChar( oParadox:FieldGet( j ) ) + " | "
   NEXT
   ? "   Dados:", cTexto
   ? "--------------------------------------------------"
RETURN
*/

//===================================================================
// CLASSE GERENCIADORA DE CURSOR ESTILO DBF PARA PARADOX
//===================================================================
CLASS ParadoxCursor
   DATA cFile
   DATA pDoc
   DATA nTotalRecords
   DATA nFields
   DATA nRecNo        // Equivalente ao RecNo() interno (1 até nTotalRecords, ou nTotalRecords + 1 se EOF)

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
   METHOD GetFields()
   METHOD FieldGet( nFieldPos )
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
         ::nRecNo := 1 // Posiciona no primeiro registro por padrão (GoTop)
      ELSE
         ::nRecNo := 0 // Vazia
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

   // Se estiver em EOF e tentar voltar, ou em BOF e tentar avançar
   ::nRecNo += nRows

   // Controla limites de EOF e BOF idênticos ao DBF
   IF ::nRecNo > ::nTotalRecords
      ::nRecNo := ::nTotalRecords + 1 // EOF
   ELSEIF ::nRecNo < 1
      ::nRecNo := 0                  // BOF (ou antes do primeiro)
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

METHOD GetFields() CLASS ParadoxCursor
   Local aNames := {}, j
   FOR j := 0 TO ::nFields - 1
      AAdd( aNames, PX_Get_Field_Name( ::pDoc, j ) )
   NEXT
RETURN aNames

METHOD FieldGet( nFieldPos ) CLASS ParadoxCursor
   // Se estiver posicionado num registro válido, busca direto via pxlib usando o índice (RecNo - 1)
   IF ::nRecNo >= 1 .AND. ::nRecNo <= ::nTotalRecords
      RETURN PX_Get_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1 )
   ENDIF
RETURN NIL