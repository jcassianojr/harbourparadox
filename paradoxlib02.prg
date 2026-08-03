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

#pragma BEGINDUMP

#include <hbapi.h>
#include <paradox.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

HB_FUNC( PX_NEW )
{
   hb_retnl( (HB_LONG) (HB_PTRDIFF) PX_new() );
}

HB_FUNC( PX_OPEN_FILE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   const char *filename = hb_parc( 2 );
   hb_retni( PX_open_file( pxdoc, (char * ) filename ) );
}

HB_FUNC( PX_CLOSE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   PX_close( pxdoc );
}

HB_FUNC( PX_DELETE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   PX_delete( pxdoc );
}

HB_FUNC( PX_GET_NUM_RECORDS )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   hb_retnl( (HB_LONG) pxdoc->px_head->px_numrecords );
}

HB_FUNC( PX_GET_NUM_FIELDS )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   hb_retni( pxdoc->px_head->px_numfields );
}

HB_FUNC( PX_GET_FIELD_NAME )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   int fieldno = hb_parni( 2 );
   if( pxdoc && pxdoc->px_head && fieldno >= 0 && fieldno < pxdoc->px_head->px_numfields ) {
      hb_retc( (char *) pxdoc->px_head->px_fields[fieldno].px_fname );
   } else {
      hb_retc( "" );
   }
}

HB_FUNC( PX_GET_FIELD_VAL )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   int recno = hb_parni( 2 );
   int fieldno = hb_parni( 3 );
   
   char *data = (char *) malloc( pxdoc->px_head->px_recordsize );
   if( data ) {
      memset(data, 0, pxdoc->px_head->px_recordsize);
      PX_get_record(pxdoc, recno, data);
      
      pxfield_t *field = &pxdoc->px_head->px_fields[fieldno];
      
      int total_len = 0;
      int k;
      for( k = 0; k < pxdoc->px_head->px_numfields; k++ ) {
         total_len += (int) pxdoc->px_head->px_fields[k].px_flen;
      }
      
      int offset = 0;
      int rec_size = (int) pxdoc->px_head->px_recordsize;
      if (total_len < rec_size) {
          offset = rec_size - total_len; 
      }
      
      for( k = 0; k < fieldno; k++ ) {
         offset += (int) pxdoc->px_head->px_fields[k].px_flen;
      }
      
      char *field_ptr = data + offset;
      int ftype = field->px_ftype;
      
      
      
      // Identifica o campo de data (Tipo 2 = Date ou Tipo 21 = Timestamp)
      int is_date_field = (ftype == 2 || ftype == 21) ? 1 : 0;

      if (is_date_field) {
         long days_val = 0;

         //===================================================================
         // Leitura direta da memória para Timestamp (Tipo 21 - 8 bytes)
         //===================================================================
         if (ftype == 21 && field->px_flen == 8) {
            unsigned char *p = (unsigned char *) field_ptr;
            // O Paradox armazena o Timestamp como um Double Big-Endian com o MSB invertido
            unsigned char buf[8];
            buf[0] = p[0] ^ 0x80; // Inverte o bit de sinal
            buf[1] = p[1]; buf[2] = p[2]; buf[3] = p[3];
            buf[4] = p[4]; buf[5] = p[5]; buf[6] = p[6]; buf[7] = p[7];
            
            // Converte para Double de forma segura de Big Endian para Little Endian (padrão do PC)
            unsigned char little_endian[8];
            little_endian[0] = buf[7]; little_endian[1] = buf[6];
            little_endian[2] = buf[5]; little_endian[3] = buf[4];
            little_endian[4] = buf[3]; little_endian[5] = buf[2];
            little_endian[6] = buf[1]; little_endian[7] = buf[0];
            
            double ms_val = 0.0;
            memcpy(&ms_val, little_endian, 8);
            
            // Converte milissegundos transcorridos desde 0001-01-01 para dias
            if (ms_val != 0.0) {
               days_val = (long) (ms_val / 86400000.0);
            }
         } 
         //===================================================================
         // Leitura da memória para Date (Tipo 2 - 4 bytes)
         //===================================================================
         else if (ftype == 2 && field->px_flen == 4) {
            unsigned char *p = (unsigned char *) field_ptr;
            days_val = (((long)(p[0] ^ 0x80)) << 24) |
                       (((long)p[1]) << 16) |
                       (((long)p[2]) << 8) |
                       ((long)p[3]);
         }

         if (days_val != 0) {
            // Algoritmo nativo de conversão Rata Die (Época Paradox: 01/01/0001)
            long rd = days_val - 1; 
            
            // Ciclo de 400 anos
            long n400 = rd / 146097;
            rd %= 146097;
            
            // Ciclo de 100 anos
            long n100 = rd / 36524;
            if (n100 == 4) n100 = 3; // Exceção bissexta
            rd -= n100 * 36524;
            
            // Ciclo de 4 anos
            long n4 = rd / 1461;
            rd %= 1461;
            
            // Ciclo de 1 ano
            long n1 = rd / 365;
            if (n1 == 4) n1 = 3; // Exceção bissexta
            rd -= n1 * 365;
            
            long year = n400 * 400 + n100 * 100 + n4 * 4 + n1 + 1;
            
            // Determina se o ano atual é bissexto
            int is_leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) ? 1 : 0;
            int days_in_month[] = {31, 28 + is_leap, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
            
            // Calcula o mês e o dia com base nos dias restantes
            long month = 1;
            int i_m = 0;
            for (i_m = 0; i_m < 12; i_m++) {
                if (rd < days_in_month[i_m]) break;
                rd -= days_in_month[i_m];
                month++;
            }
            long day = rd + 1;

            if (year >= 1000 && year <= 9999) {
               char dstr[32];
               // Formata exatamente como o Python: YYYY-MM-DD 00:00:00
               snprintf(dstr, sizeof(dstr), "%04ld-%02ld-%02ld 00:00:00", year, month, day);
               hb_retc(dstr);
            } else {
               char dstr[32];
               snprintf(dstr, sizeof(dstr), "%ld", days_val);
               hb_retc(dstr);
            }
         } else {
            hb_retc("");
         }
      }
      else if (ftype == 3) { 
         short val = 0;
         PX_get_data_short(pxdoc, field_ptr, field->px_flen, &val);
         hb_retni( (int) val );
      }
      else if (ftype == 4 || ftype == 22) { 
         long val = 0;
         PX_get_data_long(pxdoc, field_ptr, field->px_flen, &val);
         hb_retnl( (HB_LONG) val );
      }
      else if (ftype == 5 || ftype == 6) { 
         double val = 0.0;
         PX_get_data_double(pxdoc, field_ptr, field->px_flen, &val);
         hb_retnd( val );
      }
      else {
         char *valstr = NULL;
         if( PX_get_data_alpha(pxdoc, field_ptr, field->px_flen, &valstr) == 0 && valstr ) {
            hb_retc( valstr );
            free( valstr );
         } else {
            char *buf = (char *) malloc( field->px_flen + 1 );
            memcpy( buf, field_ptr, field->px_flen );
            buf[field->px_flen] = '\0';
            for( int z = 0; z < field->px_flen; z++ ) {
                if( buf[z] < 32 || buf[z] > 126 ) buf[z] = ' ';
            }
            hb_retc( buf );
            free( buf );
         }
      }
      free( data );
   } else {
      hb_retc( "ERR_MEM" );
   }
}

HB_FUNC( PX_CREATE_TABLE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   const char *filename_ptr = hb_parc( 2 );
   PHB_ITEM aStruct = hb_param( 3, HB_IT_ARRAY );
   
   if( !pxdoc || !filename_ptr || !aStruct ) {
      hb_retni( -1 );
      return;
   }

   int num_fields = (int) hb_arrayLen( aStruct );
   if( num_fields <= 0 || num_fields > 255 ) {
      hb_retni( -2 );
      return;
   }

   pxfield_t *fields = (pxfield_t *) calloc( num_fields, sizeof( pxfield_t ) );
   if( !fields ) {
      hb_retni( -3 );
      return;
   }

   int j;
   for( j = 0; j < num_fields; j++ ) {
      PHB_ITEM field_info = hb_arrayGetItemPtr( aStruct, j + 1 );
      
      if( field_info && HB_IS_ARRAY( field_info ) ) {
         const char *fname = hb_arrayGetCPtr( field_info, 1 );
         const char *ftype_str = hb_arrayGetCPtr( field_info, 2 );
         int flen = hb_arrayGetNI( field_info, 3 );
         int fdec = hb_arrayGetNI( field_info, 4 );

         // Aloca e copia o nome de forma segura, garantindo ausência de lixo de memória
         if( fname && fname[0] != '\0' ) {
            int len = strlen( fname );
            fields[j].px_fname = (char *) malloc( len + 1 );
            memcpy( fields[j].px_fname, fname, len + 1 );
         } else {
            fields[j].px_fname = (char *) malloc( 8 );
            memcpy( fields[j].px_fname, "FIELD", 6 );
         }
         
         fields[j].px_fdc = fdec;

         if( ftype_str && (ftype_str[0] == 'C' || ftype_str[0] == 'c') ) {
            fields[j].px_ftype = 1; // Alpha
            fields[j].px_flen  = (flen > 0 && flen <= 255) ? flen : 50;
         } else if( ftype_str && (ftype_str[0] == 'N' || ftype_str[0] == 'n') ) {
            if( fdec > 0 ) {
               fields[j].px_ftype = 5; // Number (Double)
               fields[j].px_flen  = 8;
            } else {
               fields[j].px_ftype = 4; // Long Integer
               fields[j].px_flen  = 4;
            }
         } else if( ftype_str && (ftype_str[0] == 'D' || ftype_str[0] == 'd') ) {
            fields[j].px_ftype = 2; // Date
            fields[j].px_flen  = 4;
         } else if( ftype_str && (ftype_str[0] == 'L' || ftype_str[0] == 'l') ) {
            fields[j].px_ftype = 9; // Logical
            fields[j].px_flen  = 1;
         } else {
            fields[j].px_ftype = 1;
            fields[j].px_flen  = 50;
         }
      }
   }

   int result = PX_create_file( pxdoc, fields, num_fields, filename_ptr, 0 );
   
   // Libera as alocações dos nomes dos campos
   for( j = 0; j < num_fields; j++ ) {
      if( fields[j].px_fname ) {
         free( fields[j].px_fname );
      }
   }
   free( fields );

   if( result < 0 ) {
      hb_retni( -4 );
      return;
   }

   hb_retni( 0 );
}

HB_FUNC( PX_APPEND_RECORD )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   PHB_ITEM aRow = hb_param( 2, HB_IT_ARRAY );

   if( !pxdoc || !pxdoc->px_head || !aRow ) {
      hb_retni( -1 );
      return;
   }

   int num_fields = pxdoc->px_head->px_numfields;
   int arr_len = (int) hb_arrayLen( aRow );

   // Recalcula o tamanho do registro para garantir que o buffer não venha zerado
   int total_len = 0;
   int k;
   for( k = 0; k < num_fields; k++ ) {
      total_len += (int) pxdoc->px_head->px_fields[k].px_flen;
   }
   
   int record_size = pxdoc->px_head->px_recordsize;
   if (record_size < total_len) {
       record_size = total_len; 
       pxdoc->px_head->px_recordsize = total_len;
   }

   // Aloca o buffer com margem de segurança
   char *rec_buf = (char *) calloc( 1, record_size + 128 );
   if( !rec_buf ) {
      hb_retni( -2 );
      return;
   }

   // Pula os bytes de controle ocultos exigidos pelo Paradox
   int offset = 0;
   if (total_len < record_size) {
       offset = record_size - total_len; 
   }

   // Preenche os dados usando as funções validadas do Harbour
   for( k = 0; k < num_fields; k++ ) {
      pxfield_t *field = &pxdoc->px_head->px_fields[k];
      char *field_ptr = rec_buf + offset;

      if ( k < arr_len ) {
         if( field->px_ftype == 1 ) { // Alpha (Texto)
            const char *str = hb_arrayGetCPtr( aRow, k + 1 );
            if ( str ) {
               int copy_len = strlen(str);
               if (copy_len > field->px_flen) copy_len = field->px_flen;
               memcpy(field_ptr, str, copy_len);
            }
         } else if( field->px_ftype == 4 ) { // Long Integer (4 bytes)
            long lval = (long) hb_arrayGetNL( aRow, k + 1 );
            PX_put_data_long( pxdoc, field_ptr, field->px_flen, lval );
         } else if( field->px_ftype == 5 || field->px_ftype == 6 ) { // Double / Currency
            double dval = (double) hb_arrayGetND( aRow, k + 1 );
            PX_put_data_double( pxdoc, field_ptr, field->px_flen, dval );
         } else if( field->px_ftype == 9 ) { // Logical
            int lval = hb_arrayGetL( aRow, k + 1 );
            field_ptr[0] = lval ? 0x81 : 0x80; // 0x81 = True, 0x80 = False no Paradox
         } else if( field->px_ftype == 2 ) { // Date
            const char *str = hb_arrayGetCPtr( aRow, k + 1 );
            if ( str ) {
               int y = 0, m = 0, d = 0;
               if( sscanf(str, "%d-%d-%d", &y, &m, &d) == 3 ) {
                  long a = (14 - m) / 12;
                  long y2 = y + 4800 - a;
                  long m2 = m + 12 * a - 3;
                  long jdn = d + (153 * m2 + 2) / 5 + 365 * y2 + y2 / 4 - y2 / 100 + y2 / 400 - 32045;
                  long p_days = jdn - 1721425; 
                  
                  PX_put_data_long( pxdoc, field_ptr, 4, p_days );
               }
            }
         }
      }

      offset += field->px_flen;
   }

   // Grava o registro utilizando a função oficial PX_put_record da pxlib
   int res = PX_put_record( pxdoc, rec_buf );
   free( rec_buf );

   // CORREÇÃO: PX_put_record retorna >= 0 em caso de sucesso (número do registro ou 0)
   hb_retni( (res >= 0) ? 0 : -3 );
}

HB_FUNC( PX_DELETE_RECORD )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   int recno = hb_parni( 2 );

   if( !pxdoc ) {
      hb_retni( -1 );
      return;
   }

   // A pxlib utiliza base 0 para o número do registro (recno de 0 até Total-1)
   int result = PX_delete_record( pxdoc, recno );

   // Retorna 0 em caso de sucesso ou -1 em caso de falha
   hb_retni( (result >= 0) ? 0 : -1 );
}

HB_FUNC( PX_RECNO )
{
   pxdoc_t *pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( 1 );
   int current_rec = hb_parni( 2 ); // Opcional: você pode passar o índice atual como parâmetro

   if( !pxdoc ) {
      hb_retni( 0 );
      return;
   }

   // Retorna o registro atual baseado no índice fornecido (convertido para base 1)
   hb_retni( current_rec + 1 );
}

#pragma ENDDUMP