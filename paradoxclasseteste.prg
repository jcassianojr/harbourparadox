#include "hbclass.ch"


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

