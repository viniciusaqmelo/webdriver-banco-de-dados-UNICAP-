-- =====================================================================
-- Webdriver - Parte 1
-- sql/parte_1/02_create_tables.sql : criacao das tabelas (modelo fisico)
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root, depois do 01_create_database.sql.
--
-- Ordem de criacao (respeita as dependencias de chave estrangeira):
--   1 plano -> 2 instituicao -> 3 usuario -> 4 administrador -> 5 arquivo
--   -> 6 compartilhamento -> 7 comentario -> 8 suporte
--   -> 9 operacao_arquivo -> 10 historico_versionamento
--
-- Nomes de restricoes: pk_<tabela>, fk_<tabela>_<referencia>,
-- uq_<tabela>_<coluna>, ck_<tabela>_<regra>.
-- Indices: o InnoDB cria automaticamente um indice para cada chave
-- estrangeira; nenhum indice adicional e necessario na Parte 1.
-- =====================================================================

USE webdriver;

-- ---------------------------------------------------------------------
-- 0. Recriacao do ambiente de testes
-- ATENCAO: apaga as tabelas e os dados. Nao execute em uma base real.
-- Ordem inversa da criacao. atividades_recentes e criada na Parte 2,
-- mas referencia arquivo, por isso e removida primeiro.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS atividades_recentes;
DROP TABLE IF EXISTS historico_versionamento;
DROP TABLE IF EXISTS operacao_arquivo;
DROP TABLE IF EXISTS suporte;
DROP TABLE IF EXISTS comentario;
DROP TABLE IF EXISTS compartilhamento;
DROP TABLE IF EXISTS arquivo;
DROP TABLE IF EXISTS administrador;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS instituicao;
DROP TABLE IF EXISTS plano;

-- ---------------------------------------------------------------------
-- 1. plano: catalogo de planos que as instituicoes podem adquirir
-- ---------------------------------------------------------------------
CREATE TABLE plano(
    id_plano            INT AUTO_INCREMENT,
    nome                VARCHAR(50)  NOT NULL,
    duracao             INT          NOT NULL,   -- em meses (A18)
    espaco_por_usuario  BIGINT       NOT NULL,   -- em bytes (A44); limite verificado pelos triggers da Parte 2 (B17)
    CONSTRAINT pk_plano PRIMARY KEY (id_plano),
    CONSTRAINT ck_plano_duracao CHECK (duracao > 0)
);

-- ---------------------------------------------------------------------
-- 2. instituicao: instituicoes e sua adesao a um plano (relacionamento ADERE)
-- ---------------------------------------------------------------------
CREATE TABLE instituicao(
    id_instituicao  INT AUTO_INCREMENT,
    nome            VARCHAR(100) NOT NULL,
    causa_social    VARCHAR(255) NOT NULL,
    endereco        VARCHAR(255) NOT NULL,
    id_plano        INT          NULL,       -- (0,1): instituicao pode nao ter plano (A05)
    data_aquisicao  DATE         NULL,       -- atributo do relacionamento ADERE (A04)
    CONSTRAINT pk_instituicao PRIMARY KEY (id_instituicao),
    -- ON DELETE omitido: o padrao do InnoDB ja impede remover um plano em uso
    -- (equivale a RESTRICT, A31). Omitido por precaucao, pois o MySQL proibe
    -- acoes referenciais em colunas usadas em CHECK (id_plano esta em ck_instituicao_adesao).
    CONSTRAINT fk_instituicao_plano FOREIGN KEY (id_plano)
        REFERENCES plano(id_plano),
    -- id_plano e data_aquisicao: ambos nulos ou ambos preenchidos (A32)
    CONSTRAINT ck_instituicao_adesao CHECK (
        (id_plano IS NULL AND data_aquisicao IS NULL) OR
        (id_plano IS NOT NULL AND data_aquisicao IS NOT NULL)
    )
);

-- ---------------------------------------------------------------------
-- 3. usuario: usuarios da plataforma (relacionamento VINCULA)
-- ---------------------------------------------------------------------
CREATE TABLE usuario(
    id_usuario      INT AUTO_INCREMENT,
    login           VARCHAR(50)  NOT NULL,
    senha_hash      VARCHAR(255) NOT NULL,   -- hash da senha, nunca texto puro (A21)
    data_ingresso   DATE         NOT NULL,
    email           VARCHAR(100) NOT NULL,
    id_instituicao  INT          NULL,       -- (0,1): usuario pode nao ter instituicao (A13)
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_login UNIQUE (login),
    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT fk_usuario_instituicao FOREIGN KEY (id_instituicao)
        REFERENCES instituicao(id_instituicao)
        ON DELETE SET NULL                   -- A31
);

-- ---------------------------------------------------------------------
-- 4. administrador: especializacao de usuario (tabela 1:1, A06)
-- ---------------------------------------------------------------------
CREATE TABLE administrador(
    id_administrador  INT AUTO_INCREMENT,
    id_usuario        INT NOT NULL,
    CONSTRAINT pk_administrador PRIMARY KEY (id_administrador),
    CONSTRAINT uq_administrador_usuario UNIQUE (id_usuario),   -- garante o 1:1
    CONSTRAINT fk_administrador_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT                   -- A31
);

-- ---------------------------------------------------------------------
-- 5. arquivo: metadados dos arquivos (relacionamento POSSUI)
-- ---------------------------------------------------------------------
CREATE TABLE arquivo(
    id_arquivo               INT AUTO_INCREMENT,
    nome                     VARCHAR(255) NOT NULL,
    tipo                     VARCHAR(100) NOT NULL,   -- texto livre (A18)
    permissoes_acesso        VARCHAR(100) NOT NULL,   -- texto livre, sem niveis (A03)
    tamanho                  BIGINT       NOT NULL,   -- em bytes (A44)
    data_ultima_modificacao  DATE         NOT NULL,   -- redundancia controlada (A16)
    localizacao              VARCHAR(255) NOT NULL,
    url                      VARCHAR(500) NOT NULL,
    id_usuario               INT          NOT NULL,   -- proprietario (imutavel, A38)
    CONSTRAINT pk_arquivo PRIMARY KEY (id_arquivo),
    -- Chave tecnica: alvo da FK composta de compartilhamento (A09).
    -- Exigida pelo MySQL 8.4+ (restrict_fk_on_non_standard_key).
    CONSTRAINT uq_arquivo_dono UNIQUE (id_arquivo, id_usuario),
    CONSTRAINT fk_arquivo_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT ck_arquivo_tamanho CHECK (tamanho >= 0)
);

-- ---------------------------------------------------------------------
-- 6. compartilhamento: relacionamento N:N COMPARTILHA
-- ---------------------------------------------------------------------
CREATE TABLE compartilhamento(
    id_arquivo             INT  NOT NULL,
    id_compartilhado       INT  NOT NULL,   -- usuario que recebeu o acesso
    id_dono                INT  NOT NULL,   -- redundancia controlada pela FK composta (A09)
    data_compartilhamento  DATE NOT NULL,
    CONSTRAINT pk_compartilhamento PRIMARY KEY (id_arquivo, id_compartilhado),   -- A30 / A11
    -- Garante que id_dono seja o proprietario real do arquivo (A09)
    CONSTRAINT fk_compartilhamento_arquivo FOREIGN KEY (id_arquivo, id_dono)
        REFERENCES arquivo(id_arquivo, id_usuario)
        ON DELETE CASCADE,                   -- A15
    CONSTRAINT fk_compartilhamento_usuario FOREIGN KEY (id_compartilhado)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT                   -- A31
    -- Regra "dono nao compartilha consigo mesmo" (A10) fica na aplicacao:
    -- id_dono participa de FK com ON DELETE CASCADE e, por isso, nao pode
    -- ser usado em CHECK no MySQL.
);

-- ---------------------------------------------------------------------
-- 7. comentario: comentarios sobre arquivos (FAZ / RECEBE)
-- ---------------------------------------------------------------------
CREATE TABLE comentario(
    id_comentario  INT AUTO_INCREMENT,
    conteudo       TEXT NOT NULL,
    data           DATE NOT NULL,
    hora           TIME NOT NULL,
    id_usuario     INT  NOT NULL,   -- autor
    id_arquivo     INT  NOT NULL,   -- arquivo comentado
    CONSTRAINT pk_comentario PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentario_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT fk_comentario_arquivo FOREIGN KEY (id_arquivo)
        REFERENCES arquivo(id_arquivo)
        ON DELETE CASCADE                    -- A15
);

-- ---------------------------------------------------------------------
-- 8. suporte: solicitacoes de suporte (SOLICITA / ATENDE / REFERENCIA)
-- ---------------------------------------------------------------------
CREATE TABLE suporte(
    id_suporte        INT AUTO_INCREMENT,
    data              DATE NOT NULL,
    hora              TIME NOT NULL,
    descricao         TEXT NOT NULL,
    id_usuario        INT  NOT NULL,   -- solicitante
    id_administrador  INT  NOT NULL,   -- responsavel (1,1) (A07)
    id_arquivo        INT  NULL,       -- arquivo relacionado, opcional (A07)
    CONSTRAINT pk_suporte PRIMARY KEY (id_suporte),
    CONSTRAINT fk_suporte_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT fk_suporte_administrador FOREIGN KEY (id_administrador)
        REFERENCES administrador(id_administrador)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT fk_suporte_arquivo FOREIGN KEY (id_arquivo)
        REFERENCES arquivo(id_arquivo)
        ON DELETE SET NULL                   -- A15
);

-- ---------------------------------------------------------------------
-- 9. operacao_arquivo: registro das operacoes (EXECUTA / SOFRE)
-- ---------------------------------------------------------------------
CREATE TABLE operacao_arquivo(
    id_operacao    INT AUTO_INCREMENT,   -- identificador artificial (A29)
    tipo_operacao  VARCHAR(10) NOT NULL,
    data           DATE        NOT NULL,
    hora           TIME        NOT NULL,
    id_usuario     INT         NOT NULL,
    id_arquivo     INT         NOT NULL,
    CONSTRAINT pk_operacao_arquivo PRIMARY KEY (id_operacao),
    CONSTRAINT fk_operacao_arquivo_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT fk_operacao_arquivo_arquivo FOREIGN KEY (id_arquivo)
        REFERENCES arquivo(id_arquivo)
        ON DELETE CASCADE,                   -- A15
    CONSTRAINT ck_operacao_arquivo_tipo CHECK (tipo_operacao IN ('carregar', 'atualizar', 'remover'))   -- A33
);

-- ---------------------------------------------------------------------
-- 10. historico_versionamento: versoes dos arquivos (TEM_VERSAO / ALTERA)
-- ---------------------------------------------------------------------
CREATE TABLE historico_versionamento(
    id_historico     INT AUTO_INCREMENT,
    data             DATE        NOT NULL,
    hora             TIME        NOT NULL,
    operacao         VARCHAR(10) NOT NULL,
    conteudo_mudado  TEXT        NOT NULL,   -- sempre em texto
    id_usuario       INT         NOT NULL,   -- usuario que alterou
    id_arquivo       INT         NOT NULL,
    CONSTRAINT pk_historico_versionamento PRIMARY KEY (id_historico),
    CONSTRAINT fk_historico_versionamento_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE RESTRICT,                  -- A31
    CONSTRAINT fk_historico_versionamento_arquivo FOREIGN KEY (id_arquivo)
        REFERENCES arquivo(id_arquivo)
        ON DELETE CASCADE,                   -- A15
    -- Somente operacoes que geram versao: 'carregar' cria a versao inicial, 'atualizar' cria nova versao.
    -- 'remover' nao gera versao (nao ha conteudo novo e o arquivo deixa de existir) - A33 revisada.
    CONSTRAINT ck_historico_versionamento_operacao CHECK (operacao IN ('carregar', 'atualizar'))
);
