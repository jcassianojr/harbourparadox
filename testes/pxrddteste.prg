REQUEST PXRDD   // Carrega a RDD do Paradox criada acima

PROCEDURE Main()
   Local cTabela := "siglas.db"
   Local i

   ? "================================================="
   ? " Teste Nativo - Paradox usando WorkAreas (PXRDD) "
   ? "================================================="

   IF !File( cTabela )
      ? "Erro: Tabela " + cTabela + " nao encontrada no diretorio!"
      RETURN
   ENDIF

   // Magica do Harbour: Abre a tabela Paradox nativamente!
   USE ( cTabela ) VIA "PXRDD" ALIAS "PARADOX"

   IF NetErr()
      ? "Erro ao abrir a tabela via RDD."
      RETURN
   ENDIF

   ? "Tabela Aberta:", Alias()
   ? "Total de Registros:", LastRec()
   ? "Total de Campos:", FCount()
   ? "-------------------------------------------------"

   // Lista a estrutura
   FOR i := 1 TO FCount()
      ? "Campo " + StrZero( i, 2 ) + ":", PadR( FieldName( i ), 15 ), FieldType( i ), FieldLen( i ), FieldDec( i )
   NEXT
   ? "-------------------------------------------------"

   // Navegacao estilo DBF
   GO TOP
   
   ? "Lendo os 5 primeiros registros fisicos..."
   i := 0
   DO WHILE !EOF() .AND. i < 5
      ? "RecNo:", RecNo(), "| ID/Campo 1:", FieldGet( 1 ), "| Campo 2:", FieldGet( 2 )
      SKIP
      i++
   ENDDO

   ? "-------------------------------------------------"
   ? "Pulando direto para o Fim da Tabela..."
   GO BOTTOM
   ? "RecNo Atual:", RecNo()
   ? "Ultimo ID/Campo 1:", FieldGet( 1 )
   
    ? hb_valtoexp(CleanDbStruct(dbstruct()))

   CLOSE DATABASES
   ? "Tabela fechada com sucesso!"

RETURN


FUNCTION CleanDbStruct( aStruct )
   Local i, cType
   For i := 1 To Len( aStruct )
      cType := aStruct[ i, 2 ] // Pega a string do tipo (ex: "C:BZEU")
      If At( ":", cType ) > 0
         // Corta tudo a partir dos dois pontos, mantendo apenas a letra base (ex: "C")
         aStruct[ i, 2 ] := SubStr( cType, 1, At( ":", cType ) - 1 )
      EndIf
   Next
RETURN aStruct