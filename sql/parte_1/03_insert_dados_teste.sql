-- =====================================================================
-- Webdriver - Parte 1
-- sql/parte_1/03_insert_dados_teste.sql : dados de teste ficticios
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root, depois do 02_create_tables.sql.
--
-- Todos os nomes, e-mails, enderecos e URLs sao ficticios.
-- Dominio .test e reservado (RFC 2606) e nao pertence a ninguem.
-- IDs informados explicitamente para que as referencias sejam previsiveis.
--
-- Senhas: o script guarda somente o hash (senha_hash), gerado com bcrypt,
-- custo 12, formato $2b$ - o mesmo algoritmo da aplicacao Python (A47).
-- As senhas ficticias de teste estao no README, secao "Credenciais
-- ficticias de teste" (P7).
--
-- Regras respeitadas nos dados:
--   - todo arquivo tem a operacao "carregar" e a 1a versao (RN21, A08);
--   - data_ultima_modificacao = data da versao mais recente (A16);
--   - id_dono do compartilhamento = proprietario do arquivo (A09);
--   - so comentam / atualizam usuarios com acesso (A01, A34).
-- =====================================================================

USE webdriver;

-- ---------------------------------------------------------------------
-- plano
-- ---------------------------------------------------------------------
INSERT INTO plano (id_plano, nome, duracao, espaco_por_usuario) VALUES
    (1, 'Básico',        12,   5368709120),   --   5 GB por usuário
    (2, 'Intermediário', 12,  21474836480),   --  20 GB por usuário
    (3, 'Avançado',      24, 107374182400);   -- 100 GB por usuário (nenhuma instituição aderiu)

-- ---------------------------------------------------------------------
-- instituicao
-- (1 e 3 aderiram ao mesmo plano em datas diferentes - A04;
--  4 ainda nao tem plano - A05)
-- ---------------------------------------------------------------------
INSERT INTO instituicao (id_instituicao, nome, causa_social, endereco, id_plano, data_aquisicao) VALUES
    (1, 'Instituto Vida Verde',         'Preservação ambiental',  'Rua das Palmeiras, 120 - Recife/PE',   2, '2026-02-10'),
    (2, 'Associação Mãos Solidárias',   'Combate à fome',         'Av. Central, 455 - Olinda/PE',         1, '2026-03-05'),
    (3, 'ONG Saber para Todos',         'Educação infantil',      'Rua do Saber, 78 - Jaboatão/PE',       2, '2026-04-20'),
    (4, 'Coletivo Arte na Rua',         'Cultura comunitária',    'Travessa das Artes, 9 - Paulista/PE',  NULL, NULL);

-- ---------------------------------------------------------------------
-- usuario
-- (5 e 6 sao administradores da plataforma, sem instituicao - A13)
-- ---------------------------------------------------------------------
INSERT INTO usuario (id_usuario, login, senha_hash, data_ingresso, email, id_instituicao) VALUES
    (1, 'ana.souza',      '$2b$12$piAoA5JY4qNXGEel.bdS2OuJQWOQGyWGRS4JKRFxgfi05TK3uruuS', '2026-02-15', 'ana.souza@exemplo.test',      1),
    (2, 'bruno.lima',     '$2b$12$k4GHikrAtX12HhRFz8AbZuo4j0pbJlfZurEQzn075KEV35hnzwONK', '2026-02-20', 'bruno.lima@exemplo.test',     1),
    (3, 'carla.mendes',   '$2b$12$yFaKa4qHZ8WnlmkV8e1t6ubA7Pn5B.xy8UND6f.gEJwtKmDf9Pjd6', '2026-03-10', 'carla.mendes@exemplo.test',   2),
    (4, 'diego.alves',    '$2b$12$nvwIgeKTwyXmyeJPOlGvP.kKGUBOHPjrFQXFFQ/8NfxlTa86oomuu', '2026-04-25', 'diego.alves@exemplo.test',    3),
    (5, 'elisa.rocha',    '$2b$12$j2gbyJeQhJyOIKtTl9Vj4.L78LK448x3ZG94pUj76B9FAelI/P.pe', '2026-01-05', 'elisa.rocha@exemplo.test',    NULL),
    (6, 'fabio.nunes',    '$2b$12$Uip1cWmBWw6nopN0ZDq7p.X0ejqrrLq9DoLE.L4/OqolbFHDPaepC', '2026-01-05', 'fabio.nunes@exemplo.test',    NULL),
    (7, 'gabriela.costa', '$2b$12$k7p15V0zeLZwODCCQbOij.gTgnVQ.NZ4kk1jiYqFDX14PyaXEWsmm', '2026-03-12', 'gabriela.costa@exemplo.test', 2),
    (8, 'henrique.dias',  '$2b$12$FtBEhpiAwLXEGZyansSB0.On/LPgD.UZqvhINej0ZDK1.1xrtGWz.', '2026-05-02', 'henrique.dias@exemplo.test',  4);

-- ---------------------------------------------------------------------
-- administrador (especializacao de usuario)
-- ---------------------------------------------------------------------
INSERT INTO administrador (id_administrador, id_usuario) VALUES
    (1, 5),
    (2, 6);

-- ---------------------------------------------------------------------
-- arquivo (somente metadados - A23)
-- ---------------------------------------------------------------------
INSERT INTO arquivo (id_arquivo, nome, tipo, permissoes_acesso, tamanho, data_ultima_modificacao, localizacao, url, id_usuario) VALUES
    (1, 'relatorio_anual_2025.pdf', 'application/pdf', 'proprietário e compartilhados', 2457600,   '2026-05-06', '/armazenamento/u1/relatorio_anual_2025.pdf', 'https://webdriver.exemplo.test/arquivos/1', 1),
    (2, 'logo_instituto.png',       'image/png',       'somente proprietário',          512000,    '2026-05-01', '/armazenamento/u1/logo_instituto.png',       'https://webdriver.exemplo.test/arquivos/2', 1),
    (3, 'video_campanha.mp4',       'video/mp4',       'proprietário e compartilhados', 157286400, '2026-05-20', '/armazenamento/u3/video_campanha.mp4',       'https://webdriver.exemplo.test/arquivos/3', 3),
    (4, 'ata_reuniao_marco.txt',    'text/plain',      'proprietário e compartilhados', 8192,      '2026-05-11', '/armazenamento/u2/ata_reuniao_marco.txt',    'https://webdriver.exemplo.test/arquivos/4', 2),
    (5, 'podcast_episodio1.mp3',    'audio/mpeg',      'somente proprietário',          31457280,  '2026-05-14', '/armazenamento/u4/podcast_episodio1.mp3',    'https://webdriver.exemplo.test/arquivos/5', 4),
    (6, 'planilha_doacoes.csv',     'text/csv',        'proprietário e compartilhados', 20480,     '2026-05-18', '/armazenamento/u7/planilha_doacoes.csv',     'https://webdriver.exemplo.test/arquivos/6', 7);

-- ---------------------------------------------------------------------
-- compartilhamento (id_dono = proprietario do arquivo - A09)
-- (arquivo 1 compartilhado entre instituicoes diferentes - A12)
-- ---------------------------------------------------------------------
INSERT INTO compartilhamento (id_arquivo, id_compartilhado, id_dono, data_compartilhamento) VALUES
    (1, 2, 1, '2026-05-02'),
    (1, 3, 1, '2026-05-03'),
    (3, 7, 3, '2026-05-10'),
    (4, 1, 2, '2026-05-12'),
    (6, 3, 7, '2026-05-15');

-- ---------------------------------------------------------------------
-- operacao_arquivo (todo arquivo tem "carregar" - RN21)
-- ---------------------------------------------------------------------
INSERT INTO operacao_arquivo (id_operacao, tipo_operacao, data, hora, id_usuario, id_arquivo) VALUES
    (1, 'carregar',  '2026-05-01', '09:15:00', 1, 1),
    (2, 'carregar',  '2026-05-01', '09:20:00', 1, 2),
    (3, 'atualizar', '2026-05-06', '14:30:00', 2, 1),   -- atualizado por usuario compartilhado (A34)
    (4, 'carregar',  '2026-05-08', '10:00:00', 3, 3),
    (5, 'carregar',  '2026-05-11', '11:00:00', 2, 4),
    (6, 'carregar',  '2026-05-14', '08:30:00', 4, 5),
    (7, 'carregar',  '2026-05-15', '13:10:00', 7, 6),
    (8, 'atualizar', '2026-05-18', '09:05:00', 3, 6),   -- atualizado por usuario compartilhado (A34)
    (9, 'atualizar', '2026-05-20', '16:45:00', 3, 3);

-- ---------------------------------------------------------------------
-- historico_versionamento (todo arquivo tem a 1a versao - A08)
-- ---------------------------------------------------------------------
INSERT INTO historico_versionamento (id_historico, data, hora, operacao, conteudo_mudado, id_usuario, id_arquivo) VALUES
    (1, '2026-05-01', '09:15:00', 'carregar',  'Versão inicial do relatório anual de 2025.',                    1, 1),
    (2, '2026-05-01', '09:20:00', 'carregar',  'Versão inicial do logotipo do instituto.',                      1, 2),
    (3, '2026-05-06', '14:30:00', 'atualizar', 'Corrigida a tabela de receitas da seção 3.',                    2, 1),
    (4, '2026-05-08', '10:00:00', 'carregar',  'Versão inicial do vídeo da campanha.',                          3, 3),
    (5, '2026-05-11', '11:00:00', 'carregar',  'Versão inicial da ata da reunião de março.',                    2, 4),
    (6, '2026-05-14', '08:30:00', 'carregar',  'Versão inicial do primeiro episódio do podcast.',               4, 5),
    (7, '2026-05-15', '13:10:00', 'carregar',  'Versão inicial da planilha de doações.',                        7, 6),
    (8, '2026-05-18', '09:05:00', 'atualizar', 'Incluídas as doações recebidas na segunda semana de maio.',     3, 6),
    (9, '2026-05-20', '16:45:00', 'atualizar', 'Substituída a trilha sonora e ajustadas as legendas finais.',   3, 3);

-- ---------------------------------------------------------------------
-- comentario (autor sempre e o dono ou um usuario compartilhado - A01)
-- ---------------------------------------------------------------------
INSERT INTO comentario (id_comentario, conteudo, data, hora, id_usuario, id_arquivo) VALUES
    (1, 'Revisei os números da seção 3, agora estão corretos.', '2026-05-06', '15:00:00', 2, 1),
    (2, 'Obrigada! Versão final aprovada pela diretoria.',      '2026-05-07', '09:00:00', 1, 1),
    (3, 'O vídeo ficou ótimo para a campanha.',                 '2026-05-11', '18:20:00', 7, 3),
    (4, 'Conferi a planilha e os totais batem com o extrato.',  '2026-05-18', '10:15:00', 3, 6);

-- ---------------------------------------------------------------------
-- suporte (com e sem arquivo relacionado - A07)
-- ---------------------------------------------------------------------
INSERT INTO suporte (id_suporte, data, hora, descricao, id_usuario, id_administrador, id_arquivo) VALUES
    (1, '2026-05-21', '10:30:00', 'O vídeo não carrega na pré-visualização.',              3, 1, 3),
    (2, '2026-05-22', '14:00:00', 'Como associar minha instituição a um plano?',           8, 2, NULL),
    (3, '2026-05-23', '09:45:00', 'Não consigo ver quem tem acesso ao relatório anual.',   1, 1, 1);
