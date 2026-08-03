from pypxlib.pxlib_ctypes import *

# Inicializa e abre o arquivo Paradox
pxdoc = PX_new()
if PX_open_file(pxdoc, b"siglas.db") == 0:
    # Acessa o ponteiro do cabeçalho
    head = pxdoc.contents.px_head.contents
    
    # Lista todos os atributos disponíveis dentro da estrutura do cabeçalho
    print("Atributos disponíveis no cabeçalho do Paradox:")
    for field_name, field_type in head._fields_:
        valor = getattr(head, field_name)
        print(f" - {field_name}: {valor}")
        
    PX_close(pxdoc)

PX_delete(pxdoc)