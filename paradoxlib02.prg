// Requer pxlib https://pxlib.sourceforge.net/
// libpx.a -Ic:\mspxlib-0.6.10\include\
// https://github.com/steinm/pxlib 


#include "fileio.ch"


PROCEDURE ParadoxCreateTable( cDbFile, aStruct )
   Local pPxDoc := NIL

   ? "Iniciando criacao e gravacao do arquivo Paradox em: " + cDbFile + " ..."

   pPxDoc := PX_New()
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      ? "Erro ao instanciar PX_New()"
      RETURN  .f.
   ENDIF

   // ETAPA 1: Criação da Estrutura e do Arquivo Vazio no caminho especificado
   IF PX_Create_Table( pPxDoc, cDbFile, aStruct ) == 0
      ? "Estrutura do Paradox criada com sucesso!"
   ELSE
      ? "Erro ao criar o arquivo Paradox no caminho informado."
      RETURN  .f.
   ENDIF

   // Limpeza segura dos ponteiros da pxlib
   PX_Close( pPxDoc )
   PX_Delete( pPxDoc )
   
   ? "Processo finalizado!"

RETURN .t.


//===================================================================
// FUNÇÃO INDEPENDENTE: Retorna a estrutura (dbStruct) de uma tabela Paradox
//===================================================================
FUNCTION Paradox_DbStruct( cDbFile )
   Local pPxDoc := NIL
   Local nNumFields := 0
   Local j, nFieldLen := 0, nFieldDec := 0, nFieldType := 0
   Local cFieldName := "", cHarbourType := "C"
   Local aStruct := {}

   IF !File( cDbFile )
      RETURN aStruct
   ENDIF

   pPxDoc := PX_New()
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      RETURN aStruct
   ENDIF

   IF PX_Open_File( pPxDoc, cDbFile ) == 0
      nNumFields := PX_Get_Num_Fields( pPxDoc )

      FOR j := 0 TO nNumFields - 1
         cFieldName := PX_Get_Field_Name( pPxDoc, j )
         
         // Obtém o tipo interno do Paradox e os tamanhos por referência
         nFieldType := PX_Get_Field_Type_And_Len( pPxDoc, j, @nFieldLen, @nFieldDec )
         
         // Mapeia o tipo do Paradox para o equivalente padrão do DBF/Harbour
         // 1 = Alpha (C)
         // 2 = Date / 21 = Timestamp (D)
         // 3 = Short / 4 = Long / 22 = AutoInc (N)
         // 5 = Number / 6 = Currency (N com decimais)
         // 9 = Logical (L)
         IF nFieldType == 1
            cHarbourType := "C"
            nFieldDec := 0
         ELSEIF nFieldType == 2 .OR. nFieldType == 21
            cHarbourType := "D"
            nFieldLen := 8
            nFieldDec := 0
         ELSEIF nFieldType >= 3 .AND. nFieldType <= 4 .OR. nFieldType == 22
            cHarbourType := "N"
            nFieldDec := 0
         ELSEIF nFieldType == 5 .OR. nFieldType == 6
            cHarbourType := "N"
            nFieldLen := Max( nFieldLen, 18 )
         ELSEIF nFieldType == 9
            cHarbourType := "L"
            nFieldLen := 1
            nFieldDec := 0
         ELSE
            cHarbourType := "C"
         ENDIF

         // Adiciona ao formato padrão: { Nome, Tipo, Tamanho, Decimais }
         AAdd( aStruct, { cFieldName, cHarbourType, Max(1, nFieldLen), nFieldDec } )
      NEXT

      PX_Close( pPxDoc )
   ENDIF

   PX_Delete( pPxDoc )

RETURN aStruct

FUNCTION Dbf_Para_Paradox( cDbfFile ,cDRIVEDES,lincdados )
   Local pPxDoc := NIL
   Local nNumFields := 0
   Local j, nTotalDbf := 0
   Local aRow := {}
   Local xVal
   Local cFieldTypeDbf
   Local lSuccess := .F.
   
   IF VALTYPE(cDRIVEDES)<>"C"
    cDRIVEDES:="DBFCDX"
   ENDIF
   
   IF VALTYPE(lincdados)<>"L"
    lincdados:=.T.
   ENDIF

   cDbTargetFile:=HB_FNAMEEXTSET(cDbFile,"db")
   

   IF !File( cDbfFile )
      ? "Erro: Arquivo DBF de origem nao encontrado: " + cDbfFile
      Return .F.
   ENDIF

   // 1. Abre o DBF de origem em modo compartilhado/leitura
   //USE ( cDbfFile ) NEW VIA "DBFCDX" SHARED ALIAS "ORIGEM"
   
   dbUseArea( .T., (cDRIVEDES), (cDbfFile), "ORIGEM", .T. , .F. )

   IF NetErr()
      ? "Erro ao abrir o arquivo DBF de origem."
      Return .F.
   ENDIF

   nNumFields := FCount()
   nTotalDbf  := LastRec()
   aStruct:=dbstruct() 
   
   
   IF .not. ParadoxCreateTable( cDbFile, aStruct )
      ? "erro criando"
      return .f.
   endif
   
   if .not. lincdados
      dbclosearea()
      return .t.
   endif

   ? "Iniciando transferencia de " + AllTrim( Str( nTotalDbf ) ) + " registros do DBF para o Paradox..."

   // 2. Instancia o documento Paradox para escrita/append
   pPxDoc := PX_New()
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      dbSELECTar("ORIGEM")
      dbclosearea()
      Return .F.
   ENDIF

   // Tenta abrir o arquivo Paradox já existente para receber os dados
   IF PX_Open_File( pPxDoc, cDbTargetFile ) == 0
      
      // 3. Varre todos os registros do DBF
      DBGOTOP()
      WHILE !EOF()
         aRow := Array( nNumFields )
         
         FOR j := 1 TO nNumFields
            xVal := FieldGet( j )
            cFieldTypeDbf := ValType( xVal )
            
            // Tratamentos específicos de conversão de tipos para o Paradox se necessário
            IF cFieldTypeDbf == "D"
               // Converte data do Harbour (YYYYMMDD) para string ISO ("YYYY-MM-DD") esperada pelo C-Pragma de Append
               IF !Empty( xVal )
                  aRow[j] := DToS( xVal )
                  aRow[j] := SubStr( aRow[j], 1, 4 ) + "-" + SubStr( aRow[j], 5, 2 ) + "-" + SubStr( aRow[j], 7, 2 )
               ELSE
                  aRow[j] := ""
               EndIf
            ELSEIF cFieldTypeDbf == "L"
               // Lógico (.T./.F.)
               aRow[j] := xVal
            ELSE
               // Caracteres e Numéricos passam direto
               aRow[j] := xVal
            EndIf
         NEXT

         // Insere o array de dados no Paradox utilizando a função nativa C-Pragma que construímos
         IF PX_Append_Record( pPxDoc, aRow ) != 0
            ? "Aviso: Falha ao inserir o registro RecNo " + AllTrim( Str( RECNO() ) )
         ENDIF

         DBSKIP()
      ENDDO

      PX_Close( pPxDoc )
      lSuccess := .T.
      ? "Transferencia para o Paradox concluida com sucesso!"
   ELSE
      ? "Erro ao abrir o arquivo Paradox de destino: " + cDbTargetFile
   ENDIF

   PX_Delete( pPxDoc )
 
   dbSELECTar("ORIGEM")
   dbclosearea()

Return lSuccess


PROCEDURE paradox_to_dbf(cDbFile,cDRIVEDES,lincdados)
 //  Local cDbFile  := "siglas.db"
 //  Local cDbfFile := "siglas_convertido.dbf"
   Local pPxDoc   := NIL
   Local nNumRecords := 0, nNumFields := 0
   Local i, j, k
   Local aStruct := {}
   Local cFieldName, nFieldType, nFieldLen, nFieldDec
   Local xVal
   Local cDbfFile
   
   
   IF VALTYPE(cDRIVEDES)<>"C"
    cDRIVEDES:="DBFCDX"
   ENDIF
   
   IF VALTYPE(lincdados)<>"L"
    lincdados:=.T.
   ENDIF

   cDbfFile:=HB_FNAMEEXTSET(cDbFile,"dbf")
   //RddSetDefault( "DBFCDX" )

   IF !File( cDbFile )
      ? "Arquivo Paradox nao encontrado: " + cDbFile
      RETURN
   ENDIF

   ? "Iniciando a leitura do Paradox para conversao em DBF..."

   pPxDoc := PX_New()
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      ? "Erro ao instanciar PX_New()"
      RETURN
   ENDIF

   IF PX_Open_File( pPxDoc, cDbFile ) == 0
      nNumRecords := PX_Get_Num_Records( pPxDoc )
      nNumfields  := PX_Get_Num_Fields( pPxDoc )

      ? "Total de Registros no Paradox: " + AllTrim( Str( nNumRecords ) )
      ? "Total de Campos no Paradox: " + AllTrim( Str( nNumfields ) )

      // 1. Mapeia a estrutura dos campos do Paradox para a estrutura do DBF do Harbour
      FOR j := 0 TO nNumfields - 1
         cFieldName := PX_Get_Field_Name( pPxDoc, j )
         
         // Descobre o tipo do campo no Paradox através do ponteiro interno da struct
         // (Fazemos uma chamada auxiliar em C embutido para pegar o ftype e tamanho exato)
         nFieldType := PX_Get_Field_Type_And_Len( pPxDoc, j, @nFieldLen, @nFieldDec )
         
         // Mapeia tipos do Paradox para tipos do Harbour:
         // Ftype 1 = Alpha (C)
         // Ftype 2 = Date / Ftype 21 = Timestamp (D)
         // Ftype 3 = Short / Ftype 4 = Long / Ftype 22 = AutoInc (N)
         // Ftype 5 = Number / Ftype 6 = Currency (N com decimais)
         IF nFieldType == 1
            AAdd( aStruct, { cFieldName, "C", Max(1, nFieldLen), 0 } )
         ELSEIF nFieldType == 2 .OR. nFieldType == 21
            AAdd( aStruct, { cFieldName, "D", 8, 0 } )
         ELSEIF nFieldType >= 3 .AND. nFieldType <= 4 .or. nFieldType == 22
            AAdd( aStruct, { cFieldName, "N", Max(1, nFieldLen), 0 } )
         ELSEIF nFieldType == 5 .OR. nFieldType == 6
            AAdd( aStruct, { cFieldName, "N", 18, 4 } )
         ELSE
            // Fallback genérico para caracteres caso encontre outro tipo
            AAdd( aStruct, { cFieldName, "C", Max(1, nFieldLen), 0 } )
         ENDIF
      NEXT

      // 2. Cria o arquivo DBF de destino com a estrutura mapeada
      IF File( cDbfFile )
         Erase( cDbfFile )
      ENDIF
      
      DbCreate( cDbfFile, aStruct, cDRIVEDES, .T., "TRG" )
      ? "Arquivo DBF criado com sucesso: " + cDbfFile

// 3. Varre todos os registros do Paradox e grava no DBF

         IF lincdados
            FOR i := 0 TO nNumRecords - 1
               ( "TRG" )->( DbAppend() )
               
               FOR j := 0 TO nNumfields - 1
                  xVal := PX_Get_Field_Val( pPxDoc, i, j )
                  
                  // Se o campo do DBF for do tipo Data (D)
                  IF aStruct[j + 1][2] == "D"
                     IF ValType( xVal ) == "C" .AND. Len( xVal ) >= 10 .AND. SubStr( xVal, 5, 1 ) == '-'
                        TRG->( FieldPut( j + 1, StoD( SubStr( xVal, 1, 4 ) + SubStr( xVal, 6, 2 ) + SubStr( xVal, 9, 2 ) ) ) )
                     ELSE
                        TRG->( FieldPut( j + 1, CToD( "" ) ) )
                     ENDIF
                  ELSE
                     TRG->( FieldPut( j + 1, xVal ) )
                  ENDIF
               NEXT
            NEXT
         ENDIF

      ( "TRG" )->( DbCloseArea() )
      PX_Close( pPxDoc )
      ? "Migracao de dados concluida com sucesso para: " + cDbfFile
   ELSE
      ? "Erro ao abrir o arquivo Paradox via PX_Open_File."
   ENDIF

   PX_Delete( pPxDoc )

RETURN


PROCEDURE paradox_to_csv(cDbFile,cSEPARADOR)
  // Local cDbFile  := "siglas.db"
  // Local cCsvFile := "siglas_exportado.csv"
  Local cCsvFile
   Local nHandleCsv
   Local pPxDoc   := NIL
   Local nNumRecords := 0, nNumFields := 0
   Local i, j
   Local cFieldNames := "", cRowData := ""
   
   cCsvFile=HB_FNAMEEXTSET(cDbFile)

    IF VALTYPE(cSEPARADOR)<>"C"
       cSEPARADOR:=";"
   ENDIF

   IF !File( cDbFile )
      ? "Arquivo Paradox nao encontrado: " + cDbFile
      RETURN
   ENDIF

   ? "Iniciando a leitura do Paradox via pxlib estatica..."

   pPxDoc := PX_New()
   
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      ? "Erro ao instanciar PX_New()"
      RETURN
   ENDIF

   IF PX_Open_File( pPxDoc, cDbFile ) == 0
      
      nHandleCsv := FCreate( cCsvFile )
      IF nHandleCsv == -1
         ? "Erro ao criar o arquivo CSV de saida."
         PX_Close( pPxDoc )
         PX_Delete( pPxDoc )
         RETURN
      ENDIF

      nNumRecords := PX_Get_Num_Records( pPxDoc )
      nNumfields  := PX_Get_Num_Fields( pPxDoc )

      ? "Total de Registros: " + AllTrim( Str( nNumRecords ) )
      ? "Total de Campos: " + AllTrim( Str( nNumfields ) )

      // Escreve o nome dos campos no CSV
      FOR j := 0 TO nNumfields - 1
         cFieldNames += PX_Get_Field_Name( pPxDoc, j ) + If( j < nNumfields - 1,cSEPARADOR, "" )
      NEXT
      FWrite( nHandleCsv, cFieldNames + hb_eol() )

      // Varre todos os registros da tabela Paradox
      FOR i := 0 TO nNumRecords - 1
         cRowData := ""
         FOR j := 0 TO nNumfields - 1
            cRowData += hb_valtostr( PX_Get_Field_Val( pPxDoc, i, j ) ) + If( j < nNumfields - 1, cSEPARADOR, "" )
         NEXT
         
         FWrite( nHandleCsv, cRowData + hb_eol() )
      NEXT

      FClose( nHandleCsv )
      PX_Close( pPxDoc )
      ? "Arquivo CSV gerado com sucesso: " + cCsvFile
   ELSE
      ? "Erro ao abrir o arquivo Paradox via PX_Open_File."
   ENDIF

   PX_Delete( pPxDoc )

RETURN

FUNCTION Paradox_Pack( cDbFile )
   Local cTempFile := cDbFile + ".tmp"
   Local pDocOrig := NIL, pDocTemp := NIL
   Local nTotalRecords := 0, nNumFields := 0
   Local aStruct := {}
   Local i, j, nFieldLen, nFieldDec, nFieldType
   Local aRow := {}
   Local lSuccess := .F.

   IF !File( cDbFile )
      ? "Erro: Arquivo Paradox nao encontrado: " + cDbFile
      RETURN .F.
   ENDIF

   // 1. Abre a tabela original para leitura
   pDocOrig := PX_New()
   IF pDocOrig == 0 .OR. pDocOrig == NIL
      RETURN .F.
   ENDIF

   IF PX_Open_File( pDocOrig, cDbFile ) != 0
      PX_Delete( pDocOrig )
      RETURN .F.
   ENDIF

   nTotalRecords := PX_Get_Num_Records( pDocOrig )
   nNumFields    := PX_Get_Num_Fields( pDocOrig )

   IF nTotalRecords <= 0
      PX_Close( pDocOrig )
      PX_Delete( pDocOrig )
      RETURN .T. // Tabela vazia já está limpa
   ENDIF

   // 2. Mapeia a estrutura de campos para criar a tabela temporária
   FOR j := 0 TO nNumFields - 1
      cFieldName := PX_Get_Field_Name( pDocOrig, j )
      nFieldType := PX_Get_Field_Type_And_Len( pDocOrig, j, @nFieldLen, @nFieldDec )
      
      // Mapeia de acordo com os tipos suportados pela sua rotina de criação
      IF nFieldType == 1
         AAdd( aStruct, { cFieldName, "C", Max(1, nFieldLen), 0 } )
      ELSEIF nFieldType == 2 .OR. nFieldType == 21
         AAdd( aStruct, { cFieldName, "D", 8, 0 } )
      ELSEIF nFieldType >= 3 .AND. nFieldType <= 4 .OR. nFieldType == 22
         AAdd( aStruct, { cFieldName, "N", Max(1, nFieldLen), 0 } )
      ELSEIF nFieldType == 5 .OR. nFieldType == 6
         AAdd( aStruct, { cFieldName, "N", 18, 4 } )
      ELSE
         AAdd( aStruct, { cFieldName, "C", Max(1, nFieldLen), 0 } )
      ENDIF
   NEXT

   // 3. Cria o arquivo temporário Paradox
   pDocTemp := PX_New()
   IF pDocTemp == 0 .OR. pDocTemp == NIL
      PX_Close( pDocOrig )
      PX_Delete( pDocOrig )
      RETURN .F.
   ENDIF

   IF PX_Create_Table( pDocTemp, cTempFile, aStruct ) == 0
      
      // 4. Copia os registros (a pxlib omite os deletados automaticamente ao iterar)
      FOR i := 0 TO nTotalRecords - 1
         aRow := {}
         FOR j := 0 TO nNumFields - 1
            AAdd( aRow, PX_Get_Field_Val( pDocOrig, i, j ) )
         NEXT
         
         // Grava no arquivo temporário limpo
         PX_Append_Record( pDocTemp, aRow )
      NEXT

      PX_Close( pDocTemp )
      lSuccess := .T.
   ENDIF

   PX_Close( pDocOrig )
   PX_Delete( pDocOrig )
   IF pDocTemp != NIL
      PX_Delete( pDocTemp )
   ENDIF

   // 5. Se tudo deu certo, substitui o arquivo original pelo temporário compactado
   IF lSuccess
      IF File( cDbFile )
         Erase( cDbFile )
      ENDIF
      
      // Remove também índices antigos dessincronizados se existirem (.PX)
      IF File( cDbFile + ".PX" )
         Erase( cDbFile + ".PX" )
      ENDIF

      Filecopy( cTempFile, cDbFile )
      ? "PACK avulso executado com sucesso para: " + cDbFile
      RETURN .T.
   ENDIF
   
    

RETURN .F.