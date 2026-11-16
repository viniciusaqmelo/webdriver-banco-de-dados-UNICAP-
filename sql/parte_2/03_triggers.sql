-- =====================================================================
-- Webdriver - Parte 2
-- sql/parte_2/03_triggers.sql : triggers
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root, depois do 02_funcao_procedures.sql (os triggers
-- usam as funcoes eh_executavel e excede_espaco).
-- Estrutura conforme a Aula 13: momento (BEFORE/AFTER), evento, FOR EACH
-- ROW e corpo BEGIN ... END. Os triggers executam com os privilegios do
-- root (DEFINER), por isso podem gravar em atividades_recentes.
--
-- Triggers do enunciado : safe_security, registrar_operacao, atualizar_acesso
-- Triggers adicionais   : safe_security_atualizacao (P9),
--                         limite_espaco_insercao e limite_espaco_atualizacao (P6)
--
-- Ordem em arquivo (o MySQL aceita varios triggers no mesmo momento/evento;
-- FOLLOWS fixa a ordem): primeiro a seguranca, depois o limite de espaco.
-- Observacao do MySQL: acoes em cascata de chave estrangeira NAO disparam
-- triggers.
-- =====================================================================

USE webdriver;

DROP TRIGGER IF EXISTS limite_espaco_insercao;
DROP TRIGGER IF EXISTS limite_espaco_atualizacao;
DROP TRIGGER IF EXISTS safe_security;
DROP TRIGGER IF EXISTS safe_security_atualizacao;
DROP TRIGGER IF EXISTS registrar_operacao;
DROP TRIGGER IF EXISTS atualizar_acesso;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Safe_security: "impeca que arquivos executaveis sejam inseridos no drive"
-- BEFORE INSERT em arquivo. Bloqueia pelo tipo (MIME) ou pela extensao
-- do nome (B07; regra na funcao eh_executavel). SIGNAL cancela a insercao.
-- ---------------------------------------------------------------------
CREATE TRIGGER safe_security
BEFORE INSERT ON arquivo
FOR EACH ROW
BEGIN
    IF eh_executavel(NEW.nome, NEW.tipo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Safe_security: arquivos executaveis nao podem ser inseridos no drive.';
    END IF;
END $$

-- ---------------------------------------------------------------------
-- Safe_security na atualizacao (P9): mesma regra no BEFORE UPDATE, para
-- impedir que um arquivo existente seja renomeado ou retipado como
-- executavel.
-- ---------------------------------------------------------------------
CREATE TRIGGER safe_security_atualizacao
BEFORE UPDATE ON arquivo
FOR EACH ROW
BEGIN
    IF eh_executavel(NEW.nome, NEW.tipo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Safe_security: um arquivo nao pode ser alterado para executavel.';
    END IF;
END $$

-- ---------------------------------------------------------------------
-- Limite de espaco por usuario (P6/B17), na insercao.
-- A soma dos arquivos do proprietario, com o novo, nao pode passar do
-- espaco_por_usuario do plano da instituicao dele. Usuario sem
-- instituicao ou sem plano nao tem limite (regra na funcao excede_espaco).
-- ---------------------------------------------------------------------
CREATE TRIGGER limite_espaco_insercao
BEFORE INSERT ON arquivo
FOR EACH ROW
FOLLOWS safe_security
BEGIN
    IF excede_espaco(NEW.id_usuario, NULL, NEW.tamanho) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Limite de espaco: os arquivos do proprietario ultrapassariam o espaco por usuario do plano.';
    END IF;
END $$

-- ---------------------------------------------------------------------
-- Limite de espaco por usuario (P6/B17), na atualizacao.
-- So verifica quando o arquivo cresce ou muda de proprietario: uma
-- alteracao que nao aumenta o espaco ocupado (ex.: mudar permissoes)
-- nunca e bloqueada, mesmo que o usuario ja esteja acima do limite
-- (ex.: depois de a instituicao trocar de plano).
-- ---------------------------------------------------------------------
CREATE TRIGGER limite_espaco_atualizacao
BEFORE UPDATE ON arquivo
FOR EACH ROW
FOLLOWS safe_security_atualizacao
BEGIN
    IF (NEW.tamanho > OLD.tamanho OR NEW.id_usuario <> OLD.id_usuario)
       AND excede_espaco(NEW.id_usuario, OLD.id_arquivo, NEW.tamanho) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Limite de espaco: os arquivos do proprietario ultrapassariam o espaco por usuario do plano.';
    END IF;
END $$

-- ---------------------------------------------------------------------
-- Registrar_operacao: "Sempre que um arquivo tiver uma nova operacao
-- atualize a data da operacao na tabela atividades_recentes"
-- AFTER INSERT em operacao_arquivo. Se o arquivo ainda nao tem linha de
-- controle (arquivo novo), ela e criada como prioritario (B04).
-- ---------------------------------------------------------------------
CREATE TRIGGER registrar_operacao
AFTER INSERT ON operacao_arquivo
FOR EACH ROW
BEGIN
    INSERT INTO atividades_recentes (id_arquivo, ultima_versao, acesso)
    VALUES (NEW.id_arquivo, NEW.data, 'prioritario')
    ON DUPLICATE KEY UPDATE ultima_versao = NEW.data;
END $$

-- ---------------------------------------------------------------------
-- Atualizar_acesso: "Sempre que um usuario conseguir acesso a um novo
-- arquivo, atualize os registros de arquivo dele tambem"
-- AFTER INSERT em compartilhamento. Interpretacao validada (B08): um novo
-- acesso e atividade no arquivo -> o registro de controle do arquivo e
-- garantido e marcado como prioritario. A data de ultima edicao nao muda,
-- pois compartilhar nao edita o arquivo.
-- ---------------------------------------------------------------------
CREATE TRIGGER atualizar_acesso
AFTER INSERT ON compartilhamento
FOR EACH ROW
BEGIN
    INSERT INTO atividades_recentes (id_arquivo, ultima_versao, acesso)
    SELECT a.id_arquivo, a.data_ultima_modificacao, 'prioritario'
    FROM arquivo a
    WHERE a.id_arquivo = NEW.id_arquivo
    ON DUPLICATE KEY UPDATE acesso = 'prioritario';
END $$

DELIMITER ;
