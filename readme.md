# Harbour Paradox Integration

Projeto em Harbour para leitura, escrita, conversão e navegação de tabelas Paradox (`.db`, `.mb`, `.px`), usando a biblioteca nativa `pxlib` e uma camada de integração em C/Harbour.

O objetivo principal é facilitar o acesso a dados Paradox com um comportamento semelhante ao de um cursor DBF, mantendo compatibilidade com rotinas de consulta, exportação e manipulação de registros.

---

## Visão geral

Este projeto reúne três partes principais:

1. **Cursor estilo DBF (`ParadoxCursor`)**
   - Navegação por registros com `GoTop`, `GoBottom`, `Skip`, `GoTo`, `Seek`, `Locate`, `Append`, `Delete` e `Pack`.
   - Acesso por nome ou posição do campo.
   - Validação de tipos e estrutura de campos.

2. **Funções de manipulação estrutural em Harbour**
   - Leitura de metadados e cabeçalhos de arquivos Paradox.
   - Extração de informações de campos, tamanho de registros e propriedades do arquivo.

3. **Integração com `pxlib`**
   - Ponte em C usando `#pragma BEGINDUMP` para usar funções como `PX_new`, `PX_open_file`, `PX_get_record`, `PX_put_record` e demais operações da biblioteca nativa.

Além disso, há suporte a exportação para `DBF/CDX` e `CSV`, além de utilitários em Python para inspeção e conversão das tabelas.

---

## Estrutura do repositório

- `paradoxclasse.prg` — classe `ParadoxCursor` e operações de navegação/CRUD
- `paradoxlib01.prg` — funções auxiliares de leitura e acesso estrutural
- `paradoxlib02.prg` — funções complementares de manipulação e integração
- `paradoxpxlib.prg` / `paradoxpxlib32.prg` — ponte para a API `pxlib`
- `pxrdd.prg` — integração/abstrações de acesso em nível de RDD
- `harbourparadox.hbp` / `harbourparadox.hbc` — projeto Harbour para compilação da biblioteca
- `testes/` — exemplos e scripts de validação
- `pythonpxlib/` — utilitários Python para exportação e análise
- `makepxlib/` — suporte para compilação da biblioteca `pxlib`

---

## Requisitos

- **Harbour** 3.2+ com `hbmk2`
- **Biblioteca `pxlib`** instalada e acessível via headers e biblioteca (`libpx.a`, `.dll` ou equivalente)
- **Compilador C** compatível com o ambiente Windows (MinGW/MSYS ou MSVC)
- **Python 3** (opcional, para os utilitários da pasta `pythonpxlib`)

---

## Compilação

No repositório já existem scripts para compilar a biblioteca em Windows:

```bat
# 64 bits
complibw64.bat

# 32 bits
complibw32.bat
```

Esses scripts executam o `hbmk2.exe` com o arquivo `harbourparadox.hbp`, utilizando a include path da `pxlib`.

Para compilar os testes de exemplo:

```bat
cd testes
compteste.bat
```

---

## Como usar

### Navegação estilo DBF

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

### Busca por campo

```harbour
IF oParadox:Seek( 1, "000123" )
   ? "Registro encontrado no RecNo:", oParadox:RecNo()
ENDIF
```

### Conversão para DBF/CDX

```harbour
// Converte a tabela .DB para .DBF e gera a estrutura de campos correspondente
paradox_to_dbf("tabela.db", "DBFCDX")
```

### Exportação direta para CSV

```harbour
paradox_to_csv("tabela.db")
```

---

## Exemplos de uso em Python

A pasta `pythonpxlib` inclui utilitários para inspecionar e exportar dados Paradox:

```bash
python pythonpxlib/paradoxtocsv.py
```

Esses scripts podem ser adaptados para apontar para o arquivo Paradox desejado e gerar CSVs prontos para análise.

---

## Observações

- O projeto foi pensado para ambientes Windows, mas a lógica de acesso pode ser adaptada para outros cenários em que a `pxlib` esteja disponível.
- O foco principal é oferecer uma camada amigável para leitura de estruturas Paradox sem precisar lidar diretamente com os detalhes binários do formato.
- A implementação cobre operações comuns de leitura e manipulação, mas pode exigir ajustes conforme a versão do arquivo Paradox ou os tipos de campo envolvidos.

---

## Próximos passos recomendados

- validar suporte a tipos mais específicos do Paradox (datas, memo, BLOB, numéricos decimais)
- ampliar conversão para outras estruturas de saída
- incluir testes automatizados para cenários reais de arquivos `.db`
- documentar exemplos de uso com tabelas maiores e complexas

Se você quiser, posso também criar uma versão mais “premium” do README com badges, tabela de recursos, screenshots e instruções de instalação para Windows/Linux.