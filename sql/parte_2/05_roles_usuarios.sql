-- Webdriver - Parte 2
-- Roles, usuários e permissões de acesso
-- Executar após 04_visoes.sql


USE webdriver;

-- Limpeza
DROP USER IF EXISTS 'ana.souza'@'%', 'bruno.lima'@'%', 'carla.mendes'@'%',
                    'diego.alves'@'%', 'elisa.rocha'@'%', 'fabio.nunes'@'%',
                    'gabriela.costa'@'%', 'henrique.dias'@'%';
DROP ROLE IF EXISTS 'PapelUsuario', 'PapelEmpresa', 'PapelAdm';

-- Roles e permissões
CREATE ROLE 'PapelUsuario', 'PapelEmpresa', 'PapelAdm';

-- PapelUsuario: seus arquivos (visao filtrada) + historicos somente leitura
GRANT SELECT, INSERT, UPDATE ON webdriver.vw_arquivos_usuario    TO 'PapelUsuario';
GRANT SELECT                 ON webdriver.vw_historico_operacoes TO 'PapelUsuario';
GRANT SELECT                 ON webdriver.vw_historico_versoes   TO 'PapelUsuario';
-- insercao de arquivo (a visao nao aceita INSERT, pois oculta id_usuario)
GRANT EXECUTE ON PROCEDURE webdriver.carregar_arquivo TO 'PapelUsuario';

-- PapelEmpresa: somente visualizacao
GRANT SELECT ON webdriver.vw_empresa_usuarios TO 'PapelEmpresa';
GRANT SELECT ON webdriver.vw_empresa_arquivos TO 'PapelEmpresa';

-- PapelAdm: permissões administrativas
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.plano                   TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.instituicao             TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.usuario                 TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.administrador           TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.arquivo                 TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.compartilhamento        TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.comentario              TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.suporte                 TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.operacao_arquivo        TO 'PapelAdm';
GRANT SELECT, INSERT, UPDATE, DELETE ON webdriver.historico_versionamento TO 'PapelAdm';
-- visoes dos administradores (ids ocultos)
GRANT SELECT ON webdriver.vw_adm_planos            TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_instituicoes      TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_usuarios          TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_arquivos          TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_compartilhamentos TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_comentarios       TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_suportes          TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_operacoes         TO 'PapelAdm';
GRANT SELECT ON webdriver.vw_adm_versoes           TO 'PapelAdm';
-- rotinas administrativas
GRANT EXECUTE ON FUNCTION  webdriver.mais_de_100_dias TO 'PapelAdm';
GRANT EXECUTE ON PROCEDURE webdriver.conta_usuarios   TO 'PapelAdm';
GRANT EXECUTE ON PROCEDURE webdriver.remover_acessos  TO 'PapelAdm';

-- Contas de usúarios
CREATE USER 'ana.souza'@'%'      IDENTIFIED WITH caching_sha2_password
    AS '$A$005$v9STtI4qGGnKch5VrMeNuAMN3qLA.1/kAkCl/xwfVyiCmio3ouPAVIOAb6Wh.JD';
CREATE USER 'bruno.lima'@'%'     IDENTIFIED WITH caching_sha2_password
    AS '$A$005$7ywexQoov9mLcxh0f90IMTxonqKobyZStE0PKYSkN4MmPLvmMah05EPW8GHeQu8';
CREATE USER 'carla.mendes'@'%'   IDENTIFIED WITH caching_sha2_password
    AS '$A$005$59QVfXbPes0UG8jC0j8r2zQwjthxNLiD5WCmOI/QrcgATeQUy87L5dUrGTlzv/5';
CREATE USER 'diego.alves'@'%'    IDENTIFIED WITH caching_sha2_password
    AS '$A$005$va1WY1ZhprqdtfHkU2hIFe.sR6KhQ9ow44jQULNJkKTaCBX3fBZ8Am6ewO7fjA0';
CREATE USER 'elisa.rocha'@'%'    IDENTIFIED WITH caching_sha2_password
    AS '$A$005$jDEyWjSFKzwK6BvlEGox0dFAKVbrdbgxetfXW8K/o.MvK6AX8TTaKvrfVA19637';
CREATE USER 'fabio.nunes'@'%'    IDENTIFIED WITH caching_sha2_password
    AS '$A$005$uyaRjreF6X2Q1cyW3OV7Eb17.cVTEoNw/JbT1wka2H8izOk0lkg6KgJC5qonme9';
CREATE USER 'gabriela.costa'@'%' IDENTIFIED WITH caching_sha2_password
    AS '$A$005$X9lcS0oaKhzqQoRuKWyg86PIwXnzdPKCmt7EmOay8eHOWfhg5rKVVFuwRW1xnK7';
CREATE USER 'henrique.dias'@'%'  IDENTIFIED WITH caching_sha2_password
    AS '$A$005$AfwuaTVmFALyVaFYfQAdnyOX9fTmSCa8RThsdUIN434AtoTWSm1wGV4jBjNVCJD';

-- Atribuicao de permissões
-- usuarios comuns
GRANT 'PapelUsuario' TO 'ana.souza'@'%', 'bruno.lima'@'%', 'carla.mendes'@'%',
                        'diego.alves'@'%', 'gabriela.costa'@'%', 'henrique.dias'@'%';
-- conta da empresa: ana.souza representa o Instituto Vida Verde (B09)
GRANT 'PapelEmpresa' TO 'ana.souza'@'%';
-- administradores (usuarios 5 e 6, que estao na tabela administrador)
GRANT 'PapelAdm' TO 'elisa.rocha'@'%', 'fabio.nunes'@'%';

-- Ativa permissões ao conectar
SET DEFAULT ROLE ALL TO 'ana.souza'@'%', 'bruno.lima'@'%', 'carla.mendes'@'%',
                        'diego.alves'@'%', 'elisa.rocha'@'%', 'fabio.nunes'@'%',
                        'gabriela.costa'@'%', 'henrique.dias'@'%';

FLUSH PRIVILEGES;

-- Verificações de permissão
SHOW GRANTS FOR 'PapelUsuario';
SHOW GRANTS FOR 'ana.souza'@'%' USING 'PapelUsuario', 'PapelEmpresa';
