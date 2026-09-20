#include "hbclass.ch"
#include "error.ch"

CLASS ParadoxCursor
   PROTECTED:
      DATA cFile
      DATA pDoc
      DATA nTotalRecords
      DATA nFields
      DATA nRecNo

   EXPORTED:
      METHOD New( cFileName )
      METHOD Open()
      METHOD Close()
      METHOD IsOpen()
      METHOD EnsureOpen( cOperation )
      METHOD GoTop()
      METHOD GoBottom()
      METHOD Skip( nRows )
      METHOD GoTo( nRec )
      METHOD Eof()
      METHOD Bof()
      METHOD RecNo()
      METHOD LastRec()
      METHOD Pack()
      
      METHOD FieldName( nFieldPos )
      METHOD FieldPos( cFieldName )
      METHOD FieldGet( nFieldPos )
      METHOD FieldPut( nFieldPos, xValue )
      METHOD Append( aRowData )
      METHOD Delete()
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

METHOD IsOpen() CLASS ParadoxCursor
RETURN ::pDoc != NIL

METHOD EnsureOpen( cOperation ) CLASS ParadoxCursor
   IF !::IsOpen()
      ::ThrowError( -1, "Tabela fechada", cOperation )
      RETURN .F.
   ENDIF
RETURN .T.

METHOD Open() CLASS ParadoxCursor
   IF ::IsOpen()
      ::Close()
   ENDIF

   IF Empty( ::cFile ) .OR. !File( ::cFile )
      RETURN .F.
   ENDIF

   ::pDoc := PX_New()

   IF ::pDoc == NIL .OR. ::pDoc == 0
      RETURN .F.
   ENDIF

   IF PX_Open_File( ::pDoc, ::cFile ) != 0
      PX_Delete( ::pDoc )
      ::pDoc := NIL
      RETURN .F.
   ENDIF

   ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
   ::nFields       := PX_Get_Num_Fields( ::pDoc )
   ::nRecNo        := If( ::nTotalRecords > 0, 1, 0 )
RETURN .T.

METHOD Close() CLASS ParadoxCursor
   IF ::pDoc != NIL
      PX_Close( ::pDoc )
      PX_Delete( ::pDoc )
   ENDIF

   ::pDoc           := NIL
   ::nTotalRecords  := 0
   ::nFields        := 0
   ::nRecNo         := 0
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
      ::nRecNo := ::nTotalRecords + 1 
   ELSEIF ::nRecNo < 1
      ::nRecNo := 0                   
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

METHOD FieldName( nFieldPos ) CLASS ParadoxCursor
   IF !::EnsureOpen( "FieldName" )
      RETURN ""
   ENDIF
   IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
      RETURN PX_Get_Field_Name( ::pDoc, nFieldPos - 1 )
   ENDIF
RETURN ""

METHOD FieldPos( cFieldName ) CLASS ParadoxCursor
   LOCAL j, cName
   
   IF !::EnsureOpen( "FieldPos" )
      RETURN 0
   ENDIF
   
   cFieldName := Upper( AllTrim( cFieldName ) )
   FOR j := 1 TO ::nFields
      cName := Upper( AllTrim( ::FieldName( j ) ) )
      IF cName == cFieldName
         RETURN j
      ENDIF
   NEXT
RETURN 0 

METHOD FieldGet( nFieldPos ) CLASS ParadoxCursor
   IF !::EnsureOpen( "FieldGet" )
      RETURN NIL
   ENDIF

   IF ::nRecNo < 1 .OR. ::nRecNo > ::nTotalRecords
      RETURN NIL
   ENDIF

   IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
      RETURN PX_Get_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1 )
   ENDIF
RETURN NIL

METHOD FieldPut( nFieldPos, xValue ) CLASS ParadoxCursor
   LOCAL lOk := .F.

   IF !::EnsureOpen( "FieldPut" )
      RETURN .F.
   ENDIF

   IF ::nRecNo >= 1 .AND. ::nRecNo <= ::nTotalRecords
      IF nFieldPos >= 1 .AND. nFieldPos <= ::nFields
         IF ::ValidateData( nFieldPos, xValue )
            lOk := ( PX_Put_Field_Val( ::pDoc, ::nRecNo - 1, nFieldPos - 1, xValue ) == 0 )
         ENDIF
      ENDIF
   ENDIF
RETURN lOk

METHOD Append( aRowData ) CLASS ParadoxCursor
   LOCAL i, nRet

   IF !::EnsureOpen( "Append" )
      RETURN .F.
   ENDIF

   IF ValType( aRowData ) != "A" .OR. Len( aRowData ) != ::nFields
      ::ThrowError( 1006, "A quantidade de valores difere da quantidade de campos", "Append" )
      RETURN .F.
   ENDIF

   FOR i := 1 TO ::nFields
      IF !::ValidateData( i, aRowData[ i ] )
         RETURN .F.
      ENDIF
   NEXT

   nRet := PX_Append_Record( ::pDoc, aRowData )

   IF nRet == 0
      ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
      ::nRecNo := ::nTotalRecords
      RETURN .T.
   ELSE
      ::ThrowError( nRet, "Falha na insercao de registro", "Append" )
   ENDIF
RETURN .F.

METHOD Delete() CLASS ParadoxCursor
   LOCAL nRet
   IF !::EnsureOpen( "Delete" )
      RETURN .F.
   ENDIF

   IF !::Eof() .AND. !::Bof()
      nRet := PX_Delete_Record( ::pDoc, ::nRecNo - 1 )
      
      IF nRet == 0
         ::nTotalRecords := PX_Get_Num_Records( ::pDoc )
         IF ::nRecNo > ::nTotalRecords
            ::nRecNo := ::nTotalRecords + 1
         ENDIF
         RETURN .T.
      ELSE
         ::ThrowError( nRet, "Erro ao deletar RecNo " + hb_valtostr(::nRecNo), "Delete" )
      ENDIF
   ENDIF
RETURN .F.

METHOD Commit() CLASS ParadoxCursor
   LOCAL lOk := .F.
   IF ::EnsureOpen( "Commit" )
      lOk := ( PX_Flush( ::pDoc ) == 0 )
   ENDIF
RETURN lOk

METHOD Locate( bCondition ) CLASS ParadoxCursor
   LOCAL nOrigem := ::nRecNo

   IF !::EnsureOpen( "Locate" )
      RETURN .F.
   ENDIF

   IF ValType( bCondition ) != "B"
      RETURN .F.
   ENDIF

   ::GoTop()

   DO WHILE !::Eof()
      IF Eval( bCondition, Self )
         RETURN .T.
      ENDIF
      ::Skip( 1 )
   ENDDO

   ::nRecNo := nOrigem
RETURN .F.

METHOD Seek( nFieldPos, xValorProcurado ) CLASS ParadoxCursor
   LOCAL nOrigem := ::nRecNo
   LOCAL i

   IF !::EnsureOpen( "Seek" )
      RETURN .F.
   ENDIF

   IF nFieldPos < 1 .OR. nFieldPos > ::nFields
      RETURN .F.
   ENDIF

   FOR i := 1 TO ::nTotalRecords
      ::GoTo( i )
      IF ::FieldGet( nFieldPos ) == xValorProcurado
         RETURN .T.
      ENDIF
   NEXT

   ::nRecNo := nOrigem
RETURN .F.

METHOD DbStruct() CLASS ParadoxCursor
   LOCAL j, nFieldLen := 0, nFieldDec := 0, nFieldType := 0
   LOCAL cFieldName := "", cHarbourType := "C"
   LOCAL aStruct := {}

   IF !::EnsureOpen( "DbStruct" ) .OR. ::nFields <= 0
      RETURN aStruct
   ENDIF

   FOR j := 0 TO ::nFields - 1
      cFieldName := PX_Get_Field_Name( ::pDoc, j )
      nFieldType := PX_Get_Field_Type_And_Len( ::pDoc, j, @nFieldLen, @nFieldDec )
      
       IF nFieldType == 1                                  
         cHarbourType := "C" 
         nFieldDec := 0
      ELSEIF nFieldType == 2 .OR. nFieldType == 21        
         cHarbourType := "D" 
         nFieldLen := 8
         nFieldDec := 0
      ELSEIF nFieldType == 3                              
         cHarbourType := "N" 
         nFieldLen := 6
         nFieldDec := 0
      ELSEIF nFieldType == 4 .OR. nFieldType == 16        
         cHarbourType := "N" 
         nFieldLen := 10
         nFieldDec := 0
      ELSEIF nFieldType == 5 .OR. nFieldType == 6 .OR. nFieldType == 17 
         cHarbourType := "B" 
         nFieldLen := Max( nFieldLen, 18 )
      ELSEIF nFieldType == 9                              
         cHarbourType := "L" 
         nFieldLen := 1
         nFieldDec := 0
      ELSEIF nFieldType == 12 .OR. nFieldType == 13 .OR. nFieldType == 14 
         cHarbourType := "M" 
         nFieldLen := 10
         nFieldDec := 0
      ELSE
         cHarbourType := "C"  
      ENDIF
      
      AAdd( aStruct, { cFieldName, cHarbourType, Max(1, nFieldLen), nFieldDec } )
   NEXT

RETURN aStruct

METHOD GetFields() CLASS ParadoxCursor
   LOCAL aNames := {}, j
   
   IF !::EnsureOpen( "GetFields" )
      RETURN aNames
   ENDIF
   
   FOR j := 1 TO ::nFields
      AAdd( aNames, ::FieldName( j ) )
   NEXT
RETURN aNames

METHOD Pack() CLASS ParadoxCursor
   LOCAL cTempFile := ::cFile + ".tmp"
   LOCAL pDocTemp := NIL
   LOCAL nTotal := ::LastRec()
   LOCAL aStruct := ::DbStruct() 
   LOCAL i, j, nFields
   LOCAL aRow := {}
   LOCAL lOk := .F.

   IF !::EnsureOpen( "Pack" ) .OR. ::nTotalRecords == 0
      RETURN .T.
   ENDIF

   nFields := ::nFields
   pDocTemp := PX_New()
   IF pDocTemp == 0 .OR. pDocTemp == NIL
      RETURN .F.
   ENDIF

   IF PX_Create_Table( pDocTemp, cTempFile, aStruct ) == 0
      FOR i := 1 TO nTotal
         ::GoTo( i )
         aRow := {}
         FOR j := 1 TO nFields
            AAdd( aRow, ::FieldGet( j ) )
         NEXT
         PX_Append_Record( pDocTemp, aRow )
      NEXT

      PX_Close( pDocTemp )
      PX_Delete( pDocTemp )
      lOk := .T.
   ENDIF

   IF lOk
      ::Close()
      IF File( ::cFile )
         Erase( ::cFile )
      ENDIF
      FileCOPY( cTempFile, ::cFile )
      ::Open() 
      ? "PACK executado com sucesso! Registros deletados removidos."
   ENDIF

RETURN lOk

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
   
   oErr:Severity    := 2 
   oErr:GenCode     := EG_DATATYPE
   oErr:SubSystem   := "PXLIB"
   oErr:SubCode     := nErrorCode
   oErr:Operation   := cOperation
   
   DO CASE
      CASE nErrorCode == -1
         oErr:Description := "Parametros invalidos ou ponteiro nulo."
      CASE nErrorCode == -2
         oErr:Description := "Falha de alocacao de memoria no buffer interno."
      CASE nErrorCode == -3
         oErr:Description := "Erro interno da pxlib ao tentar persistir."
      CASE nErrorCode == 1006
         oErr:Description := cContext
      OTHERWISE
         oErr:Description := "Erro desconhecido da pxlib (" + hb_valtostr(nErrorCode) + ")"
   ENDCASE
   
   oErr:Args := { cContext }
   Eval( ErrorBlock(), oErr )
RETURN .F.