.DB (TypSammlung.DB): ? o arquivo principal da tabela. Ele armazena os dados est ticos e os registros em si em uma estrutura baseada em blocos.

.MB (TypSammlung.MB): Significa Memo Blob. Armazena campos do tipo texto longo (memo) ou dados bin rios (BLOBs) que nAo cabem diretamente dentro das linhas do arquivo .DB principal.

.PX (TypSammlung.PX): ? o arquivo de !ndice prim rio (Primary Index). Guarda a  rvore de busca (B-tree) para chaves prim rias e ordena?aes r pidas da tabela.

.VAL (TypSammlung.VAL): Armazena regras de valida?Ao de dados e restri?aes de integridade definidas para os campos da tabela.

.sch (TYPSAMMLUNG.sch): Cont,m o esquema estrutural ou informa?aes auxiliares de defini?Ao/esquema da tabela.

.X02 / .X0C e .Y02 / .Y0C: SAo arquivos de !ndices secund rios (.Xnn / .Ynn). O Paradox cria essas extensaes numeradas para gerenciar !ndices secund rios adicionais criados sobre os campos da tabela para agilizar buscas e relacionamentos.



A biblioteca pxlib foi projetada especificamente para interagir com o ecossistema de arquivos do banco de dados Paradox. Em termos de arquivos físicos suportados, a pxlib possui capacidade de manipulação para os seguintes itens:

    Arquivos de Tabela Principal (.DB)

        Leitura e Escrita: É o foco principal da biblioteca. Ela consegue abrir, ler o cabeçalho estrutural, ler registros individuais, inserir novos registros, atualizar dados, marcar registros como deletados e criar novas tabelas do zero.

    Arquivos de Blobs e Campos Memo (.MB)

        Leitura e Escrita: A pxlib possui suporte (através de funções específicas como PX_set_blob_file e manipuladores de dados blob/gráficos) para ler e gravar dados que ficam armazenados separadamente no arquivo de Memo/Blob .MB.

    Arquivos de Índice Primário (.PX)

        Leitura e Escrita: A biblioteca suporta a leitura e a criação de arquivos de índice primário correspondentes às tabelas Paradox.

    Arquivos de Índice Secundário (.Xnn / .Ynn)

        Leitura/Manipulação: Versões recentes da pxlib (a partir da 0.6.0) trouxeram melhorias significativas no suporte e na manipulação de índices secundários, embora muitos desenvolvedores tratem os arquivos de índices secundários diretamente à parte ou deixem que a aplicação gerencie, visto que compartilham semelhanças estruturais com arquivos de banco de dados.

    Arquivos Criptografados

        Descriptografia: A pxlib consegue ler tabelas Paradox protegidas por senha/criptografia, mesmo que você não saiba a senha original de acesso.

O que a pxlib NÃO manipula diretamente:

    Arquivos de regras de validação (.VAL) ou de metadados de formulários/relatórios do Paradox (.fsl, .rep, .not, etc.). A pxlib é restrita estritamente aos dados, estruturas de campos, blobs e índices da tabela, ignorando regras visuais ou de interface do antigo programa Paradox da Borland.