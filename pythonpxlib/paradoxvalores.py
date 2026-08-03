from pypxlib.pxlib_ctypes import *

pxdoc = PX_new()
PX_open_file(pxdoc, b"siglas.db")

num_fields = PX_get_num_fields(pxdoc)
print('siglas.db has %d fields:' % num_fields)

for i in range(num_fields):
    field = PX_get_field(pxdoc, i)
    print(field.contents.px_fname)

# Close the file:
PX_close(pxdoc)
# Free the memory associated with pxdoc:
PX_delete(pxdoc)
