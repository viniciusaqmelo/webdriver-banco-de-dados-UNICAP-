-- =====================================================================
-- Webdriver - Parte 2
-- sql/parte_2/01_atividades_recentes.sql : tabela extra de controle de arquivos
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root, depois dos scripts 01 a 03 da Parte 1.
--
-- Enunciado: "Crie uma tabela extra para controle de arquivos (...)
-- Nenhum usuario pode ter acesso a esta tabela exceto o usuario Root."
--   Id_arquivo(FK)  - id do arquivo que esta sendo avaliado;
--   Ultima_versao   - date com a ultima data editada do arquivo;
--   Acesso          - prioritario ou nao prioritario.
--
-- Acesso restrito ao root: nenhuma role recebe privilegio sobre esta
-- tabela (05_roles_usuarios.sql). Ela so e alterada pelo root e pelos triggers e
-- procedures, que executam com os privilegios do root (DEFINER).
-- =====================================================================

USE webdriver;

DROP TABLE IF EXISTS atividades_recentes;   -- permite reexecutar o script

CREATE TABLE atividades_recentes(
    id_arquivo     INT         NOT NULL,
    ultima_versao  DATE        NOT NULL,
    acesso         VARCHAR(15) NOT NULL,
    -- Uma linha por arquivo (tabela de controle do arquivo) - B02
    CONSTRAINT pk_atividades_recentes PRIMARY KEY (id_arquivo),
    -- Arquivo removido -> linha de controle removida (mesma politica de A15)
    CONSTRAINT fk_atividades_recentes_arquivo FOREIGN KEY (id_arquivo)
        REFERENCES arquivo(id_arquivo)
        ON DELETE CASCADE,
    CONSTRAINT ck_atividades_recentes_acesso CHECK (acesso IN ('prioritario', 'nao_prioritario'))   -- B03
);

-- Carga inicial: uma linha para cada arquivo ja existente, com a data da
-- ultima edicao. Todos comecam como prioritario (B04); a alternancia e
-- feita pela procedure chavear (02_funcao_procedures.sql). Os arquivos
-- novos entram pelos triggers registrar_operacao e atualizar_acesso
-- (03_triggers.sql).
INSERT INTO atividades_recentes (id_arquivo, ultima_versao, acesso)
SELECT id_arquivo, data_ultima_modificacao, 'prioritario'
FROM arquivo;
