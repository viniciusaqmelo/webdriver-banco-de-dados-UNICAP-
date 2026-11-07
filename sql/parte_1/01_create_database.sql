-- =====================================================================
-- Webdriver - Parte 1
-- sql/parte_1/01_create_database.sql : criacao da base de dados
-- SGBD alvo: MySQL 9.7 LTS (compativel com 8.4 LTS e 26.7)
-- Executar como root.
-- =====================================================================

-- IF NOT EXISTS: o script pode ser executado de novo sem erro e nunca
-- apaga dados. Para recriar o ambiente de testes do zero, o script
-- 02_create_tables.sql remove e recria as tabelas.
-- utf8mb4 ja e o padrao desde o MySQL 8.0; declarado explicitamente para
-- que todos os servidores da equipe usem o mesmo conjunto de caracteres.
CREATE DATABASE IF NOT EXISTS webdriver
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE webdriver;
