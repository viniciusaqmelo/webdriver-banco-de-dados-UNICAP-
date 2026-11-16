-- =====================================================================
-- Webdriver - Parte 2
-- sql/parte_2/04_visoes.sql : visoes (views)
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root, depois do 03_triggers.sql.
-- Estrutura conforme a Aula 11: CREATE VIEW <nome> AS <SELECT>.
--
-- Enunciado:
--  - o usuario so vera e ira operar arquivos que ele possua acesso;
--  - os administradores terao acesso a toda base de dados;
--  - o usuario tera acesso ao historico de operacoes, apenas visualizacao;
--  - em todas as visoes os ids estao ocultos.
--
-- Identificacao do usuario conectado (B01): cada usuario da plataforma
-- tem uma conta MySQL com o mesmo login (05_roles_usuarios.sql). As visoes comparam
-- usuario.login com SUBSTRING_INDEX(USER(), '@', 1).
-- USER() devolve a conta que esta conectada; CURRENT_USER() nao serve,
-- porque dentro de uma view SQL SECURITY DEFINER ele devolve o root.
--
-- Regra de acesso a um arquivo (RN16): ser o proprietario OU ter
-- recebido o arquivo por compartilhamento.
-- Nenhuma visao expoe atividades_recentes (somente o root) nem senha_hash.
-- =====================================================================

USE webdriver;

DROP VIEW IF EXISTS vw_arquivos_usuario;
DROP VIEW IF EXISTS vw_historico_operacoes;
DROP VIEW IF EXISTS vw_historico_versoes;
DROP VIEW IF EXISTS vw_empresa_usuarios;
DROP VIEW IF EXISTS vw_empresa_arquivos;
DROP VIEW IF EXISTS vw_adm_planos;
DROP VIEW IF EXISTS vw_adm_instituicoes;
DROP VIEW IF EXISTS vw_adm_usuarios;
DROP VIEW IF EXISTS vw_adm_arquivos;
DROP VIEW IF EXISTS vw_adm_compartilhamentos;
DROP VIEW IF EXISTS vw_adm_comentarios;
DROP VIEW IF EXISTS vw_adm_suportes;
DROP VIEW IF EXISTS vw_adm_operacoes;
DROP VIEW IF EXISTS vw_adm_versoes;

-- =====================================================================
-- 1. Visoes do usuario (PapelUsuario)
-- =====================================================================

-- 1.1 Arquivos que o usuario conectado pode ver e operar.
--     Tabela unica (sem JOIN) para a visao continuar atualizavel (UPDATE).
--     INSERT pela visao nao e possivel (id_usuario e obrigatorio e fica
--     oculto): a insercao do PapelUsuario e feita pela procedure
--     carregar_arquivo (P5/B16).
CREATE VIEW vw_arquivos_usuario AS
SELECT a.nome,
       a.tipo,
       a.permissoes_acesso,
       a.tamanho,
       a.data_ultima_modificacao,
       a.localizacao,
       a.url
FROM arquivo a
WHERE a.id_usuario IN (SELECT u.id_usuario
                       FROM usuario u
                       WHERE u.login = SUBSTRING_INDEX(USER(), '@', 1))
   OR a.id_arquivo IN (SELECT c.id_arquivo
                       FROM compartilhamento c
                       JOIN usuario u ON u.id_usuario = c.id_compartilhado
                       WHERE u.login = SUBSTRING_INDEX(USER(), '@', 1));

-- 1.2 Historico de operacoes (carregar, atualizar, remover) dos arquivos
--     a que o usuario tem acesso. Somente leitura (GRANT apenas SELECT).
CREATE VIEW vw_historico_operacoes AS
SELECT a.nome          AS arquivo,
       o.tipo_operacao AS operacao,
       o.data,
       o.hora,
       u.login         AS executada_por
FROM operacao_arquivo o
JOIN arquivo a ON a.id_arquivo = o.id_arquivo
JOIN usuario u ON u.id_usuario = o.id_usuario
WHERE a.id_usuario IN (SELECT us.id_usuario
                       FROM usuario us
                       WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1))
   OR a.id_arquivo IN (SELECT c.id_arquivo
                       FROM compartilhamento c
                       JOIN usuario us ON us.id_usuario = c.id_compartilhado
                       WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1));

-- 1.3 Historico de versionamento dos arquivos a que o usuario tem acesso.
--     Somente leitura (GRANT apenas SELECT).
CREATE VIEW vw_historico_versoes AS
SELECT a.nome            AS arquivo,
       h.data,
       h.hora,
       h.operacao,
       h.conteudo_mudado,
       u.login           AS alterado_por
FROM historico_versionamento h
JOIN arquivo a ON a.id_arquivo = h.id_arquivo
JOIN usuario u ON u.id_usuario = h.id_usuario
WHERE a.id_usuario IN (SELECT us.id_usuario
                       FROM usuario us
                       WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1))
   OR a.id_arquivo IN (SELECT c.id_arquivo
                       FROM compartilhamento c
                       JOIN usuario us ON us.id_usuario = c.id_compartilhado
                       WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1));

-- =====================================================================
-- 2. Visoes da empresa/instituicao (PapelEmpresa)
--    A conta com PapelEmpresa e a de um usuario da instituicao; ela ve os
--    usuarios da mesma instituicao e os arquivos que eles possuem (B09).
-- =====================================================================

CREATE VIEW vw_empresa_usuarios AS
SELECT i.nome AS instituicao,
       u.login,
       u.email,
       u.data_ingresso
FROM usuario u
JOIN instituicao i ON i.id_instituicao = u.id_instituicao
WHERE u.id_instituicao = (SELECT us.id_instituicao
                          FROM usuario us
                          WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1));

CREATE VIEW vw_empresa_arquivos AS
SELECT i.nome  AS instituicao,
       u.login AS proprietario,
       a.nome  AS arquivo,
       a.tipo,
       a.tamanho,
       a.data_ultima_modificacao,
       a.localizacao,
       a.url
FROM arquivo a
JOIN usuario u     ON u.id_usuario = a.id_usuario
JOIN instituicao i ON i.id_instituicao = u.id_instituicao
WHERE u.id_instituicao = (SELECT us.id_instituicao
                          FROM usuario us
                          WHERE us.login = SUBSTRING_INDEX(USER(), '@', 1));

-- =====================================================================
-- 3. Visoes dos administradores (PapelAdm): toda a base, sem ids.
--    atividades_recentes fica de fora (somente root) e senha_hash tambem.
-- =====================================================================

CREATE VIEW vw_adm_planos AS
SELECT p.nome, p.duracao, p.espaco_por_usuario
FROM plano p;

CREATE VIEW vw_adm_instituicoes AS
SELECT i.nome, i.causa_social, i.endereco, p.nome AS plano, i.data_aquisicao
FROM instituicao i
LEFT JOIN plano p ON p.id_plano = i.id_plano;

CREATE VIEW vw_adm_usuarios AS
SELECT u.login, u.email, u.data_ingresso,
       i.nome AS instituicao,
       CASE WHEN ad.id_administrador IS NULL THEN 'nao' ELSE 'sim' END AS administrador
FROM usuario u
LEFT JOIN instituicao i    ON i.id_instituicao = u.id_instituicao
LEFT JOIN administrador ad ON ad.id_usuario = u.id_usuario;

CREATE VIEW vw_adm_arquivos AS
SELECT a.nome, a.tipo, a.permissoes_acesso, a.tamanho, a.data_ultima_modificacao,
       a.localizacao, a.url, u.login AS proprietario
FROM arquivo a
JOIN usuario u ON u.id_usuario = a.id_usuario;

CREATE VIEW vw_adm_compartilhamentos AS
SELECT a.nome AS arquivo, dono.login AS dono, dest.login AS compartilhado_com, c.data_compartilhamento
FROM compartilhamento c
JOIN arquivo a      ON a.id_arquivo = c.id_arquivo
JOIN usuario dono   ON dono.id_usuario = c.id_dono
JOIN usuario dest   ON dest.id_usuario = c.id_compartilhado;

CREATE VIEW vw_adm_comentarios AS
SELECT a.nome AS arquivo, u.login AS autor, cm.conteudo, cm.data, cm.hora
FROM comentario cm
JOIN arquivo a ON a.id_arquivo = cm.id_arquivo
JOIN usuario u ON u.id_usuario = cm.id_usuario;

CREATE VIEW vw_adm_suportes AS
SELECT s.data, s.hora, s.descricao,
       sol.login  AS solicitante,
       adm_u.login AS administrador,
       a.nome     AS arquivo_relacionado
FROM suporte s
JOIN usuario sol       ON sol.id_usuario = s.id_usuario
JOIN administrador adm ON adm.id_administrador = s.id_administrador
JOIN usuario adm_u     ON adm_u.id_usuario = adm.id_usuario
LEFT JOIN arquivo a    ON a.id_arquivo = s.id_arquivo;

CREATE VIEW vw_adm_operacoes AS
SELECT a.nome AS arquivo, o.tipo_operacao AS operacao, o.data, o.hora, u.login AS executada_por
FROM operacao_arquivo o
JOIN arquivo a ON a.id_arquivo = o.id_arquivo
JOIN usuario u ON u.id_usuario = o.id_usuario;

CREATE VIEW vw_adm_versoes AS
SELECT a.nome AS arquivo, h.data, h.hora, h.operacao, h.conteudo_mudado, u.login AS alterado_por
FROM historico_versionamento h
JOIN arquivo a ON a.id_arquivo = h.id_arquivo
JOIN usuario u ON u.id_usuario = h.id_usuario;
