#ifndef PXLIB_HARBOUR_BATCH_H
#define PXLIB_HARBOUR_BATCH_H

#include <hbapi.h>
#include <hbapiitm.h>
#include <paradox.h>

PXLIB_API int PXLIB_CALL
PX_open_file_readonly( pxdoc_t *pxdoc, const char *filename );

PXLIB_API int PXLIB_CALL
PX_retrieve_records( pxdoc_t *pxdoc, int start, int count, pxval_t **records );

PXLIB_API void PXLIB_CALL
PX_free_records( pxdoc_t *pxdoc, pxval_t *records, int count );

static pxdoc_t *pxdoc_from_harbour_param( int param )
{
   pxdoc_t *pxdoc = (pxdoc_t *) hb_parptr( param );

   if( !pxdoc )
      pxdoc = (pxdoc_t *) (HB_PTRDIFF) hb_parnl( param );

   return pxdoc;
}

static void px_days_to_harbour_date( long days, char *buffer, size_t size )
{
   long rd, n400, n100, n4, n1, year, month, day;
   int leap, days_in_month[ 12 ], i;

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
      snprintf( buffer, size, "%ld", days );
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
   snprintf( buffer, size, "%04ld-%02ld-%02ld 00:00:00", year, month, day );
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
                  px_days_to_harbour_date( value->value.lval, date, sizeof( date ) );
                  hb_itemPutC( item, date );
                  break;
               }
               case pxfTimestamp:
               {
                  char date[ 32 ];
                  px_days_to_harbour_date(
                     (long) ( value->value.dval / 86400000.0 ),
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

#endif
