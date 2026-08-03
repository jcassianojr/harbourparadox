# Harbour Paradox Integration (`hb-paradox`)

Projeto desenvolvido em **Harbour** para leitura, escrita, conversao e navegacao estilo WorkArea (`DBF`) em tabelas do formato **Paradox** (`.db`, `.mb`, `.px`), utilizando a biblioteca nativa C **`pxlib`** em conjunto com blocos `#pragma BEGINDUMP`.

---

## ?? Estrutura do Projeto

O codigo esta dividido em tres grandes modulos logicos:

1. **Classe Gerenciadora de Cursor (`ParadoxCursor`)**: Simulacao completa de navegacao estilo DBF (`GoTop`, `GoBottom`, `Skip`, `Eof`, `Bof`, `RecNo`, `Seek`, `Locate`, `Append`, `Delete`).


2. **Funcoes Harbour Puro**: Manipulacao e leitura estrutural de cabecalhos e metadados de arquivos Paradox (`.db`) diretamente via manipulacao de arquivos de baixo nivel (`FOpen`, `FRead`).


3. **Funcoes Harbour com `libpx**`: Rotinas de alto nivel para exportacao/conversao de Paradox para `DBF` (`DBFCDX`) e `CSV`, alem de criacao de novas tabelas.


4. **C-Pragma (`#pragma BEGINDUMP`)**: Ponte (Bridge) em C puro integrando as funcoes da API da `pxlib` (`PX_new`, `PX_open_file`, `PX_get_record`, `PX_put_record`, etc.) para dentro do ecossistema do Harbour.



---

## ?? Como Utilizar

### 1. Navegacao Estilo DBF (`ParadoxCursor`)

A classe gerencia os ponteiros de forma transparente, permitindo navegar por tabelas Paradox como se fossem arquivos `.dbf` nativos do Harbour:

```harbour
LOCAL oParadox := ParadoxCursor():New("tabela.db")

IF oParadox:Open()
   oParadox:GoTop()
   
   WHILE !oParadox:Eof()
      ? "Registro:", oParadox:RecNo(), "| Valor:", oParadox:FieldGet(1)
      oParadox:Skip(1)
   ENDWHILE

   oParadox:Close()
ENDIF
```

### 2. Conversao de Paradox para DBF + CDX
Voce pode converter tabelas inteiras mantendo a compatibilidade de tipos e gerando indices ordenados via RDD `DBFCDX`:

```harbour
// Converte a tabela .DB para .DBF e gera a estrutura de campos correspondente
paradox_to_dbf("tabela.db", "DBFCDX")
```

### 3. Exportacao Direta para CSV
```harbour
paradox_to_csv("tabela.db")
```

---

## ?? Requisitos e Compilacao

* Compilador **Harbour** (versao 3.2 ou superior).
* Biblioteca **`pxlib`** (arquivos de cabecalho `.h` e biblioteca estatica `libpx.a` ou DLL).
* No script de compilacao, certifique-se de incluir o diretorio de inclusao da `pxlib` (`-I`) e linkar com a biblioteca C correspondente.

```