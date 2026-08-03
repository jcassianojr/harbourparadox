// Requer pxlib https://pxlib.sourceforge.net/
// libpx.a -Ic:\mspxlib-0.6.10\include\
// https://github.com/steinm/pxlib 


#include "fileio.ch"


PROCEDURE paradox_from_estrutura( cDbFile, aStruct )
   Local pPxDoc := NIL

   ? "Iniciando criacao e gravacao do arquivo Paradox em: " + cDbFile + " ..."

   pPxDoc := PX_New()
   IF pPxDoc == 0 .OR. pPxDoc == NIL
      ? "Erro ao instanciar PX_New()"
      RETURN
   ENDIF

   // ETAPA 1: Criação da Estrutura e do Arquivo Vazio no caminho especificado
   IF PX_Create_Table( pPxDoc, cDbFile, aStruct ) == 0
      ? "Estrutura do Paradox criada com sucesso!"
   ELSE
      ? "Erro ao criar o arquivo Paradox no caminho informado."
   ENDIF

   // Limpeza segura dos ponteiros da pxlib
   PX_Close( pPxDoc )
   PX_Delete( pPxDoc )
   
   ? "Processo finalizado!"

RETURN



PROCEDURE paradox_to_dbf(cDbFile,cDRIVEDES)
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

   cDbfFile:=HB_FNAMEEXTSET(cDbFile)
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


      ( "TRG" )->( DbCloseArea() )
      PX_Close( pPxDoc )
      ? "Migracao de dados concluida com sucesso para: " + cDbfFile
   ELSE
      ? "Erro ao abrir o arquivo Paradox via PX_Open_File."
   ENDIF

   PX_Delete( pPxDoc )

RETURN


PROCEDURE paradox_to_csv(cDbFile)
  // Local cDbFile  := "siglas.db"
  // Local cCsvFile := "siglas_exportado.csv"
  Local cCsvFile
   Local nHandleCsv
   Local pPxDoc   := NIL
   Local nNumRecords := 0, nNumFields := 0
   Local i, j
   Local cFieldNames := "", cRowData := ""
   
   cCsvFile=HB_FNAMEEXTSET(cDbFile)

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
         cFieldNames += PX_Get_Field_Name( pPxDoc, j ) + If( j < nNumfields - 1, ";", "" )
      NEXT
      FWrite( nHandleCsv, cFieldNames + hb_eol() )

      // Varre todos os registros da tabela Paradox
      FOR i := 0 TO nNumRecords - 1
         cRowData := ""
         FOR j := 0 TO nNumfields - 1
            cRowData += hb_valtostr( PX_Get_Field_Val( pPxDoc, i, j ) ) + If( j < nNumfields - 1, ";", "" )
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

