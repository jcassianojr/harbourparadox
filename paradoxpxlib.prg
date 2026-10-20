#pragma BEGINDUMP

#include <hbapi.h>
#include <hbapiitm.h>
#include <paradox.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

/* ===================================================================== */
/* HELPER FUNCTIONS (Migradas do antigo pxlib_harbour_batch.h)           */
/* ===================================================================== */

PXLIB_API int PXLIB_CALL PX_open_file_readonly( pxdoc_t *pxdoc, const char *filename );
PXLIB_API int PXLIB_CALL PX_retrieve_records( pxdoc_t *pxdoc, int start, int count, pxval_t **records );
PXLIB_API void PXLIB_CALL PX_free_records( pxdoc_t *pxdoc, pxval_t *records, int count );

static pxdoc_t *pxdoc_from_harbour_param( int param )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( param );

   if( !pxdoc )
      pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( param );

   return pxdoc;
}

/* 
 * Uso estrito de int32_t ao inves de long para evitar 
 * divergencias (em Linux 64b 'long' tem 8 bytes, em Windows tem 4 bytes) 
 */
static void px_days_to_harbour_date( int32_t days, char *buffer, size_t size )
{
   int32_t rd, n400, n100, n4, n1, year, month, day;
   int leap, i;
   int days_in_month[ 12 ];

   if( days == 0 )
   {
      buffer[ 0 ] = '\0';
      return;
   }

   rd = days - 1;
   n400 = rd / 146097;
   rd %= 146097;
   n100 = rd / 36524;
   if( n100 == 4 )
      n100 = 3;
   rd -= n100 * 36524;
   n4 = rd / 1461;
   rd %= 1461;
   n1 = rd / 365;
   if( n1 == 4 )
      n1 = 3;
   rd -= n1 * 365;
   year = n400 * 400 + n100 * 100 + n4 * 4 + n1 + 1;

   if( year < 1000 || year > 9999 )
   {
      snprintf( buffer, size, "%d", (int)days );
      return;
   }

   leap = ( year % 4 == 0 && year % 100 != 0 ) || year % 400 == 0;
   days_in_month[ 0 ] = 31;
   days_in_month[ 1 ] = 28 + leap;
   days_in_month[ 2 ] = 31;
   days_in_month[ 3 ] = 30;
   days_in_month[ 4 ] = 31;
   days_in_month[ 5 ] = 30;
   days_in_month[ 6 ] = 31;
   days_in_month[ 7 ] = 31;
   days_in_month[ 8 ] = 30;
   days_in_month[ 9 ] = 31;
   days_in_month[ 10 ] = 30;
   days_in_month[ 11 ] = 31;

   month = 1;
   for( i = 0; i < 12 && rd >= days_in_month[ i ]; i++ )
   {
      rd -= days_in_month[ i ];
      month++;
   }
   day = rd + 1;
   snprintf( buffer, size, "%04d-%02d-%02d 00:00:00", (int)year, (int)month, (int)day );
}


/* ===================================================================== */
/* HARBOUR API WRAPPERS                                                  */
/* ===================================================================== */

HB_FUNC( PX_NEW )
{
   hb_retptr( (void *) PX_new() );
}

HB_FUNC( PX_OPEN_FILE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   const char *filename = hb_parc( 2 );
   hb_retni( pxdoc && filename ? PX_open_file( pxdoc, filename ) : -1 );
}

HB_FUNC( PX_OPEN_FILE2 )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   const char *filename = hb_parc( 2 );

   if( !pxdoc || !filename ) {
      hb_retni( -1 );
      return;
   }

   hb_retni( PX_open_file( pxdoc, filename ) );
}

HB_FUNC( PX_CLOSE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   if( pxdoc ) {
      PX_close( pxdoc );
   }
}

HB_FUNC( PX_DELETE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   if( pxdoc ) {
      PX_delete( pxdoc );
   }
}

HB_FUNC( PX_DELETE2 )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   if( pxdoc ) {
      PX_delete( pxdoc );
   }
   hb_ret();
}

HB_FUNC( PX_GET_NUM_RECORDS )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   if( pxdoc && pxdoc->px_head ) {
      hb_retnl( (HB_LONG) pxdoc->px_head->px_numrecords );
   } else {
      hb_retnl( 0 );
   }
}

HB_FUNC( PX_GET_NUM_FIELDS )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   if( pxdoc && pxdoc->px_head ) {
      hb_retni( pxdoc->px_head->px_numfields );
   } else {
      hb_retni( 0 );
   }
}

HB_FUNC( PX_GET_FIELD_NAME )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   int fieldno = hb_parni( 2 );
   if( pxdoc && pxdoc->px_head && fieldno >= 0 && fieldno < pxdoc->px_head->px_numfields ) {
      hb_retc( (char *) pxdoc->px_head->px_fields[fieldno].px_fname );
   } else {
      hb_retc( "" );
   }
}

HB_FUNC( PX_GET_FIELD_VAL )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   int recno = hb_parni( 2 );
   int fieldno = hb_parni( 3 );
   
   if( !pxdoc || !pxdoc->px_head || recno < 0 ||
       fieldno < 0 || fieldno >= pxdoc->px_head->px_numfields ) {
      hb_ret();
      return;
   }

   char *data = (char *) malloc( pxdoc->px_head->px_recordsize );
   if( !data ) {
      hb_ret();
      return;
   }

   memset(data, 0, pxdoc->px_head->px_recordsize);
   if( !PX_get_record(pxdoc, recno, data) ) {
      free( data );
      hb_ret();
      return;
   }

   {
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
      
      int is_date_field = (ftype == 2 || ftype == 21) ? 1 : 0;

      if (is_date_field) {
         int32_t days_val = 0;

         if (ftype == 21 && field->px_flen == 8) {
            unsigned char *p = (unsigned char *) field_ptr;
            unsigned char buf[8];
            buf[0] = p[0] ^ 0x80;
            buf[1] = p[1]; buf[2] = p[2]; buf[3] = p[3];
            buf[4] = p[4]; buf[5] = p[5]; buf[6] = p[6]; buf[7] = p[7];
            
            unsigned char little_endian[8];
            little_endian[0] = buf[7]; little_endian[1] = buf[6];
            little_endian[2] = buf[5]; little_endian[3] = buf[4];
            little_endian[4] = buf[3]; little_endian[5] = buf[2];
            little_endian[6] = buf[1]; little_endian[7] = buf[0];
            
            double ms_val = 0.0;
            memcpy(&ms_val, little_endian, 8);
            
            if (ms_val != 0.0) {
               days_val = (int32_t) (ms_val / 86400000.0);
            }
         } 
         else if (ftype == 2 && field->px_flen == 4) {
            unsigned char *p = (unsigned char *) field_ptr;
            days_val = (int32_t)( (((uint32_t)(p[0] ^ 0x80)) << 24) |
                                  (((uint32_t)p[1]) << 16) |
                                  (((uint32_t)p[2]) << 8) |
                                  ((uint32_t)p[3]) );
         }

         if (days_val != 0) {
            int32_t rd = days_val - 1; 
            int32_t n400 = rd / 146097;
            rd %= 146097;
            int32_t n100 = rd / 36524;
            if (n100 == 4) n100 = 3;
            rd -= n100 * 36524;
            int32_t n4 = rd / 1461;
            rd %= 1461;
            int32_t n1 = rd / 365;
            if (n1 == 4) n1 = 3;
            rd -= n1 * 365;
            
            int32_t year = n400 * 400 + n100 * 100 + n4 * 4 + n1 + 1;
            int is_leap = ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) ? 1 : 0;
            int days_in_month[] = {31, 28 + is_leap, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
            
            int32_t month = 1;
            int i_m = 0;
            for (i_m = 0; i_m < 12; i_m++) {
                if (rd < days_in_month[i_m]) break;
                rd -= days_in_month[i_m];
                month++;
            }
            int32_t day = rd + 1;

            if (year >= 1000 && year <= 9999) {
               char dstr[32];
               snprintf(dstr, sizeof(dstr), "%04d-%02d-%02d 00:00:00", (int)year, (int)month, (int)day);
               hb_retc(dstr);
            } else {
               char dstr[32];
               snprintf(dstr, sizeof(dstr), "%d", (int)days_val);
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
            if( !buf ) {
               free( data );
               hb_ret();
               return;
            }
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
   }
}

HB_FUNC( PX_GET_FIELD_TYPE_AND_LEN )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   int fieldno = hb_parni( 2 );
   
   if( pxdoc && pxdoc->px_head && fieldno >= 0 && fieldno < pxdoc->px_head->px_numfields ) {
      pxfield_t *field = &pxdoc->px_head->px_fields[fieldno];
      hb_storni( (int) field->px_flen, 3 );
      hb_storni( (int) field->px_fdc, 4 );
      hb_retni( field->px_ftype );
   } else {
      hb_retni( 0 );
   }
}

HB_FUNC( PX_CREATE_TABLE )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
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
            fields[j].px_ftype = 1;
            fields[j].px_flen  = (flen > 0 && flen <= 255) ? flen : 50;
         } else if( ftype_str && (ftype_str[0] == 'N' || ftype_str[0] == 'n') ) {
            if( fdec > 0 ) {
               fields[j].px_ftype = 5;
               fields[j].px_flen  = 8;
            } else {
               fields[j].px_ftype = 4;
               fields[j].px_flen  = 4;
            }
         } else if( ftype_str && (ftype_str[0] == 'D' || ftype_str[0] == 'd') ) {
            fields[j].px_ftype = 2;
            fields[j].px_flen  = 4;
         } else if( ftype_str && (ftype_str[0] == 'L' || ftype_str[0] == 'l') ) {
            fields[j].px_ftype = 9;
            fields[j].px_flen  = 1;
         } else {
            fields[j].px_ftype = 1;
            fields[j].px_flen  = 50;
         }
      }
   }

   int result = PX_create_file( pxdoc, fields, num_fields, filename_ptr, 0 );
   
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
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   PHB_ITEM aRow = hb_param( 2, HB_IT_ARRAY );

   if( !pxdoc || !pxdoc->px_head || !aRow ) {
      hb_retni( -1 );
      return;
   }

   int num_fields = pxdoc->px_head->px_numfields;
   int arr_len = (int) hb_arrayLen( aRow );

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

   char *rec_buf = (char *) calloc( 1, record_size + 128 );
   if( !rec_buf ) {
      hb_retni( -2 );
      return;
   }

   int offset = 0;
   if (total_len < record_size) {
       offset = record_size - total_len; 
   }

   for( k = 0; k < num_fields; k++ ) {
      pxfield_t *field = &pxdoc->px_head->px_fields[k];
      char *field_ptr = rec_buf + offset;

      if ( k < arr_len ) {
         if( field->px_ftype == 1 ) {
            const char *str = hb_arrayGetCPtr( aRow, k + 1 );
            if ( str ) {
               int copy_len = strlen(str);
               if (copy_len > field->px_flen) copy_len = field->px_flen;
               memcpy(field_ptr, str, copy_len);
            }
         } else if( field->px_ftype == 4 ) {
            long lval = (long) hb_arrayGetNL( aRow, k + 1 );
            PX_put_data_long( pxdoc, field_ptr, field->px_flen, lval );
         } else if( field->px_ftype == 5 || field->px_ftype == 6 ) {
            double dval = (double) hb_arrayGetND( aRow, k + 1 );
            PX_put_data_double( pxdoc, field_ptr, field->px_flen, dval );
         } else if( field->px_ftype == 9 ) {
            int lval = hb_arrayGetL( aRow, k + 1 );
            field_ptr[0] = lval ? 0x81 : 0x80;
         } else if( field->px_ftype == 2 ) {
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

   int res = PX_put_record( pxdoc, rec_buf );
   free( rec_buf );

   hb_retni( (res >= 0) ? 0 : -3 );
}

HB_FUNC( PX_DELETE_RECORD )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   int recno = hb_parni( 2 );

   if( !pxdoc ) {
      hb_retni( -1 );
      return;
   }

   int result = PX_delete_record( pxdoc, recno );
   hb_retni( (result >= 0) ? 0 : -1 );
}

HB_FUNC( PX_RECNO )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( 1 );
   int current_rec = hb_parni( 2 );

   if( !pxdoc ) {
      hb_retni( 0 );
      return;
   }

   hb_retni( current_rec + 1 );
}

HB_FUNC( PX_OPEN_FILE_READONLY )
{
   pxdoc_t *pxdoc = pxdoc_from_harbour_param( 1 );
   const char *filename = hb_parc( 2 );

   hb_retni( pxdoc && filename ? PX_open_file_readonly( pxdoc, filename ) : -1 );
}

HB_FUNC( PX_GET_RECORDS )
{
   pxdoc_t *pxdoc = pxdoc_from_harbour_param( 1 );
   int start = hb_parni( 2 );
   int requested = hb_parni( 3 );
   pxval_t *records = NULL;
   int count, numfields, i, j;
   PHB_ITEM rows;

   if( !pxdoc || !pxdoc->px_head || start < 0 || requested < 0 )
   {
      hb_ret();
      return;
   }

   count = PX_retrieve_records( pxdoc, start, requested, &records );
   if( count < 0 )
   {
      hb_ret();
      return;
   }

   numfields = pxdoc->px_head->px_numfields;
   rows = hb_itemArrayNew( (HB_SIZE) count );
   if( !rows )
   {
      PX_free_records( pxdoc, records, count );
      hb_ret();
      return;
   }

   for( i = 0; i < count; i++ )
   {
      PHB_ITEM row = hb_itemArrayNew( (HB_SIZE) numfields );

      if( !row )
      {
         hb_itemRelease( rows );
         PX_free_records( pxdoc, records, count );
         hb_ret();
         return;
      }

      for( j = 0; j < numfields; j++ )
      {
         pxval_t *value = &records[ (size_t) i * (size_t) numfields + (size_t) j ];
         PHB_ITEM item = hb_itemNew( NULL );

         if( value->isnull )
         {
            if( value->type == pxfAlpha || value->type == pxfDate ||
                value->type == pxfTimestamp )
               hb_itemPutC( item, "" );
            else if( value->type == pxfLogical )
               hb_itemPutL( item, HB_FALSE );
            else if( value->type == pxfNumber || value->type == pxfCurrency )
               hb_itemPutND( item, 0.0 );
            else
               hb_itemPutNInt( item, 0 );
         }
         else
         {
            switch( value->type )
            {
               case pxfAlpha:
               case pxfGraphic:
               case pxfBLOb:
               case pxfFmtMemoBLOb:
               case pxfMemoBLOb:
               case pxfOLE:
               case pxfBytes:
               case pxfBCD:
                  if( value->value.str.val )
                     hb_itemPutCL( item, value->value.str.val,
                                   (HB_SIZE) value->value.str.len );
                  else
                     hb_itemPutC( item, "" );
                  break;
               case pxfDate:
               {
                  char date[ 32 ];
                  px_days_to_harbour_date( (int32_t) value->value.lval, date, sizeof( date ) );
                  hb_itemPutC( item, date );
                  break;
               }
               case pxfTimestamp:
               {
                  char date[ 32 ];
                  px_days_to_harbour_date(
                     (int32_t) ( value->value.dval / 86400000.0 ),
                     date, sizeof( date ) );
                  hb_itemPutC( item, date );
                  break;
               }
               case pxfShort:
               case pxfLong:
               case pxfTime:
               case pxfAutoInc:
                  hb_itemPutNInt( item, (HB_MAXINT) value->value.lval );
                  break;
               case pxfCurrency:
               case pxfNumber:
                  hb_itemPutND( item, value->value.dval );
                  break;
               case pxfLogical:
                  hb_itemPutL( item, value->value.lval == 1 ||
                               ( value->value.lval & 0xFFL ) == 0x81 );
                  break;
               default:
                  hb_itemPutC( item, "" );
                  break;
            }
         }

         hb_arraySet( row, (HB_SIZE) j + 1, item );
         hb_itemRelease( item );
      }

      hb_arraySet( rows, (HB_SIZE) i + 1, row );
      hb_itemRelease( row );
   }

   PX_free_records( pxdoc, records, count );
   hb_itemReturnRelease( rows );
}

#pragma ENDDUMP


