#include "dbstruct.ch"
#INCLUDE "TRY.CH"
#INCLUDE "DBINFO.CH"


FUNCTION DBF2Paradox( cDbfOrigem, cParadoxDestino )
   LOCAL oConn, oRs, nI, aStruct, cConnString
   
   // Lógica de destino automático [cite: 1, 7]
   IF Empty( cParadoxDestino )
      cParadoxDestino := hb_FNameDir( cDbfOrigem ) + hb_FNameName( cDbfOrigem ) + ".db"
   ENDIF
   
   // 1. Abre o DBF original
   IF !File( cDbfOrigem )
      MDT( "Arquivo DBF não encontrado: " + cDbfOrigem )
      RETURN .F.
   ENDIF

   USE (cDbfOrigem) ALIAS ORIGEM SHARED NEW
   aStruct := dbStruct()
   
   /*
   // 1. Verifica quantos índices existem no CDX/NTX
   nTotalIndices := dbOrderInfo(DBOI_ORDERCOUNT)
   
   // 2. Se houver pelo menos um índice, pega a expressão dele
   IF nTotalIndices > 0
      cPrimaryKey := MDPCHAVEI(dbOrderInfo( DBOI_EXPRESSION, , 1 ))
     // alert(cPrimaryKey)
   ENDIF
   
   // 3. Fallback: Se não houver índice ou a expressão for vazia, 
   // usamos o primeiro campo da estrutura como chave (segurança absoluta)
   IF Empty( cPrimaryKey )
      cPrimaryKey := aStruct[1][1]
   ENDIF
   */
   
   // 2. Cria a estrutura [cite: 3, 7]
   IF !ParadoxCreateTable( cParadoxDestino, aStruct) //,cPrimaryKey )
      DBCLOSEAREA()
      RETURN .F.
   ENDIF

   // 3. Conexão Manual para Testes
   // Substitua o caminho abaixo pelo caminho real da pasta onde o arquivo .db será criado
   cConnString := "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=" + hb_FNameDir( cParadoxDestino ) + ";Extended Properties=Paradox 5.x;"
   
   oConn := CreateObject( "ADODB.Connection" )
   oConn:ConnectionString := cConnString
   oConn:Mode := 3 // adModeReadWrite
   oConn:Open()

   // 4. Abre o Recordset [cite: 4]
   /*
   oRs := CreateObject( "ADODB.Recordset" )
   //oRs:Open( hb_FNameName(cParadoxDestino), oConn, 1, 3 ) 
   oRs:CursorLocation := 3 // adUseClient (Força o uso de cursor em memória, evitando bloqueios do disco)
   oRs:Open( "SELECT * FROM " + hb_FNameName(cParadoxDestino), oConn, 2, 3 )
   
   //oRs:Open( hb_FNameName(cParadoxDestino), oConn, 2, 4 )
   */
   
   oRs := CreateObject( "ADODB.Recordset" )
   //oRs:Open( hb_FNameName(cParadoxDestino), oConn, 1, 3 ) 
   oRs:CursorLocation := 3 // adUseClient (Força o uso de cursor em memória, evitando bloqueios do disco)
   //oRs:Open( "SELECT * FROM " + hb_FNameName(cParadoxDestino), oConn, 1, 2 )
  oRs:Open( hb_FNameName(cParadoxDestino), oConn, 1, 2 )

   // 5. Loop de migração [cite: 5]
   SELECT ORIGEM
   DbGoTop()
   WHILE !Eof()
      /*
      mSql := "INSERT INTO " + hb_FNameName(cParadoxDestino) + " VALUES "
      msql := msql + "("
      FOR i := 1 TO Len( aStruct )
         mFldNm := aStruct[ i, DBS_NAME ]
         IF i > 1
            mSql += ", "
         ENDIF
         mSql += c2sql( &mFldNm )
      NEXT
      mSql += ")"
      oConn:Execute(MSQL)
      */
      
      /*
      cCAMPOS:=""
      cVALORES:=""
      // Dentro do seu loop de gravação:
      FOR nI := 1 TO Len( aStruct )
         cCampos  += "[" + AllTrim(aStruct[nI][1]) + "],"
         cValores += "'" + hb_ValToStr(FieldGet(nI)) + "',"
      NEXT
      cCampos  := Left(cCampos, Len(cCampos)-1)
      cValores := Left(cValores, Len(cValores)-1)

      // O uso de colchetes no nome da tabela e nos campos é OBRIGATÓRIO no Paradox via Jet
      cSql := "INSERT INTO [" + hb_FNameName(cParadoxDestino)  + "] (" + cCampos + ") VALUES (" + cValores + ")"
      oConn:Execute( cSql )
      */
      
      
      oRs:AddNew()
      FOR nI := 1 TO Len( aStruct )
         oRs:Fields( aStruct[nI][1] ):Value := hb_FieldGet( nI )
      NEXT
      oRs:Update()
      
      DbSkip()
   ENDDO

   // 6. Limpeza [cite: 6]
   oRs:Close()
   oConn:Close()
   DBCLOSEAREA()
   
   MDT( "Migração concluída com sucesso!" )
RETURN .T.

FUNCTION DBF2Paradoxadordd( cDbfOrigem, cParadoxDestino, cPrimaryKey  )
   LOCAL aStruct, nI, oConn, oCat, oTable, oRs
   LOCAL cDir 
   LOCAL cFile 
   
   IF VALTYPE(cParadoxDestino)<>"C"
      cParadoxDestino:=TROCAEXT(cDbfOrigem,".db")
   ENDIF
   
   
   cDir := hb_FNameDir( cParadoxDestino )
   cFile := hb_FNameName( cParadoxDestino )
   // 1. Abre o DBF original (RDD padrão)
   IF !File( cDbfOrigem )
      MDT( "Arquivo DBF não encontrado: " + cDbfOrigem )
      RETURN .F.
   ENDIF
   
   //DBUseArea( <lNewArea> , <cDriver> , <cName>, <xcAlias> , <lShared> , <lReadOnly>,<cCodePage>,<nConnection> ) -> lSuccess
  
   dbUseArea( .F.,, cDbfOrigem,"ORIGEM", .T., .F. )
   
   //USE (cDbfOrigem) ALIAS ORIGEM SHARED NEW
   aStruct := dbStruct()
   
   // 2. Cria a estrutura no Paradox usando a lógica ADOX anterior
   IF ! ParadoxCreateTable( cParadoxDestino, aStruct )
      DBSELECTAR("ORIGEM")
      DBCLOSEAREA()
      RETURN .F.
   ENDIF
   
   // 3. Abre o Paradox via ADORDD para inserir os dados
   // O Paradox aqui é tratado como uma tabela via ADO
      hb_adoSetTable(cFILE)
   // Verifique se o seu ADORDD suporta "PARADOX" ou se requer "MSDASQL" com DSN
   hb_adoSetEngine("PARADOX")
   dbUseArea(.F.,"ADORDD",(cParadoxDestino),"DESTINO",.T.,.F.)

   
   
  // USE (cParadoxDestino) ALIAS DESTINO VIA "ADORDD" NEW
   
   // 4. Loop de migração (Simetria de gravação)
   //SELECT ORIGEM
  
   DBSELECTAR("ORIGEM")
   
   dbGoTop()
   WHILE !Eof()
      DBSELECTAR( "DESTINO")
      DBAPPEND()
      
      FOR nI := 1 TO Len( aStruct )
         // Transfere o campo do DBF para o campo do Paradox
         FieldPut( nI, ORIGEM->(hb_FieldGet( nI )) )
      NEXT
      
      DBSELECTAR("ORIGEM")
      DBSKIP()
   ENDDO
   
   DBSELECTAR("ORIGEM")
   DBCLOSEAREA()
   DBSELECTAR( "DESTINO")
   DBCLOSEAREA()
   
   MDT( "Migração concluída com sucesso para: " + cParadoxDestino )
RETURN .T.


