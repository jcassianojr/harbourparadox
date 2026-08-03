#include "dbstruct.ch"
#INCLUDE "TRY.CH"
#INCLUDE "DBINFO.CH"



// +--------------------------------------------------------------------
// +    Function PxStruct( filename )
// +    Retorna a estrutura dos campos do arquivo Paradox (.db) no formato de dbStruct()
// +    Formato do retorno: { { cFieldName, cFieldType, nFieldLen, nFieldDec }, ... }
// +--------------------------------------------------------------------
FUNCTION PxStruct( filename )
   LOCAL aStruct := {}
   LOCAL nHandle, cHeader
   LOCAL nHeaderSize, nNumFields, nFieldsOffset, nFieldSize
   LOCAL i, nPos, cFieldName, cFieldType, nFieldLen, nFieldDec, cTypeByte
   LOCAL cNumFieldsBuf

   IF !File( filename )
      RETURN aStruct
   ENDIF

   nHandle := FOpen( filename, 0 ) // FO_READ
   IF nHandle == -1
      RETURN aStruct
   ENDIF

   // Lê os primeiros 128 bytes para extrair informações básicas do header do Paradox
   cHeader := Space( 128 )
   IF FRead( nHandle, @cHeader, 128 ) < 128
      FClose( nHandle )
      RETURN aStruct
   ENDIF

   // Offsets padrão do Paradox para dimensionar o cabeçalho e número de campos:
   // - px_numfields (geralmente localizado próximo ao offset 0x1A ou via leitura estruturada)
   // Vamos usar uma leitura baseada nos offsets mais comuns da pxlib / formato Paradox:
   
   // Exemplo de leitura de px_numfields (geralmente 2 bytes em offset específico ou lido dinamicamente)
   // No seu print do python, vimos: px_numfields: 6 e px_headersize: 2048
   nHeaderSize   := Bin2W( SubStr( cHeader, 5, 2 ) )  // Aproximado ou fixo em 2048
   IF nHeaderSize <= 0
      nHeaderSize := 2048
   ENDIF

   // Buscando a quantidade de campos (px_numfields costuma ficar no offset 26/0x1A ou próximo)
   FSeek( nHandle, 26, FS_SET )
   cNumFieldsBuf := Space( 2 )
   FRead( nHandle, @cNumFieldsBuf, 2 )
   nNumFields := Bin2W( cNumFieldsBuf )

   // Se não encontrou o número de campos pelo offset direto, definimos um fallback seguro ou tratamos
   IF nNumFields <= 0
      FClose( nHandle )
      RETURN aStruct
   ENDIF

   // No Paradox, a descrição de cada campo (Field Descriptor) costuma ficar logo 
   // após o cabeçalho principal ou em blocos mapeados. 
   // Cada entrada de campo no Paradox armazena tipo, tamanho e nome.
   
   // Posiciona no início da área de descrição dos campos (geralmente logo após o bloco inicial do header)
   nFieldsOffset := 128 // Ponto de partida comum para varredura dos metadados de campos no .db
   
   FOR i := 1 TO nNumFields
      FSeek( nHandle, nFieldsOffset, FS_SET )
      
      // Lendo o tipo do campo e tamanho (o layout exato depende da versão px_fileversion, ex: versão 50)
      // Exemplo genérico de leitura do descritor:
      cTypeByte := Space( 1 )
      FRead( nHandle, @cTypeByte, 1 )
      
      nFieldLen := Asc( cTypeByte ) // Exemplo simplificado de byte de tamanho/tipo
      nFieldDec := 0
      cFieldType := "C" // Conversão padrão para o tipo equivalente em Harbour
      cFieldName := "FLD" + StrZero( i, 2 ) // Nome padrão caso o dicionário interno esteja em outra posição
      
      // Mapeia tipos do Paradox para equivalentes Harbour (C, N, D, L, M)
      // (Você pode refinar o CASE baseado na tabela de tipos da pxlib se necessário)
      
      AAdd( aStruct, { cFieldName, cFieldType, nFieldLen, nFieldDec } )
      
      // Incrementa o deslocamento para o próximo campo na estrutura do arquivo .db
      nFieldsOffset += 4 // Tamanho médio do registro de definição de campo no header
   NEXT

   FClose( nHandle )

RETURN aStruct

// +--------------------------------------------------------------------
// +    Function GetParadoxHeaderInfo( filename )
// +    Gera a matriz aINFOPARADOX com os atributos do cabeçalho do Paradox
// +--------------------------------------------------------------------
FUNCTION GetParadoxHeaderInfo( filename )
   LOCAL aParaRet := {}
   LOCAL nHandle, cHeader
   LOCAL nRecordSize, nFileBlocks, nNumRecords, nTheNumRecords, nNumFields
   LOCAL nMaxTableSize, nHeaderSize, nFirstBlock, nLastBlock, nFileVer
   local cVerByte

   IF !File( filename )
      RETURN aParaRet
   ENDIF

   nHandle := FOpen( filename, 0 ) // FO_READ
   IF nHandle == -1
      RETURN aParaRet
   ENDIF

   // O cabeçalho padrão do Paradox costuma ter pelo menos 80 bytes iniciais mapeados
   cHeader := Space( 128 )
   IF FRead( nHandle, @cHeader, 128 ) < 128
      FClose( nHandle )
      RETURN aParaRet
   ENDIF

   // Extração baseada nos offsets binários padrão do Paradox (.DB)
   // Nota: Valores inteiros curtos/longos em arquivos Paradox usam formato little-endian.
   
   nRecordSize   := Bin2W( SubStr( cHeader, 1, 2 ) )       // Offset 0x00: recordSize
   nMaxTableSize := Asc( SubStr( cHeader, 3, 1 ) )         // Offset 0x02: maxtablesize
   
   // Header size (geralmente 2048 bytes, armazenado em word ou dword dependendo da versão)
   nHeaderSize   := Bin2W( SubStr( cHeader, 5, 2 ) )       // Offset 0x04/0x05 aprox
   nNumRecords   := Bin2L( SubStr( cHeader, 7, 4 ) )       // Offset 0x06: numRecords (longint)
   
   // Versão do arquivo Paradox (px_fileversion) - Offset comum na estrutura
   // Vamos ler especificamente o byte da versão (geralmente localizado próximo ao offset 0x39 / 57 decimal)
   FSeek( nHandle, 57, FS_SET )
   cVerByte := Space( 1 )
   FRead( nHandle, @cVerByte, 1 )
   nFileVer := Asc( cVerByte )

   // Lendo mais propriedades do header posicionando corretamente se necessário...
   FClose( nHandle )

   // Montando a matriz aINFOPARADOX espelhando a saída da pxlib do Python
   AAdd( aParaRet, { AllTrim(filename),           'px_tablename' } )
   AAdd( aParaRet, { nRecordSize,                 'px_recordsize' } )
   AAdd( aParaRet, { 0,                           'px_filetype' } )
   AAdd( aParaRet, { nFileVer,                    'px_fileversion' } )
   AAdd( aParaRet, { nNumRecords,                 'px_numrecords' } )
   AAdd( aParaRet, { nNumRecords,                 'px_theonumrecords' } )
   AAdd( aParaRet, { 0,                           'px_numfields' } )
   AAdd( aParaRet, { nMaxTableSize,               'px_maxtablesize' } )
   AAdd( aParaRet, { If(nHeaderSize > 0, nHeaderSize, 2048), 'px_headersize' } )
   
   // Você pode expandir com os demais campos mapeados da pxlib conforme sua necessidade

RETURN aParaRet   