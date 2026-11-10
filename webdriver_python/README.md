# Webdriver — Projeto de Banco de Dados (UNICAP)

Banco de dados de uma plataforma de armazenamento e compartilhamento de arquivos para instituições sociais, com aplicação em Python.

**Equipe:** Caio Vilela, Guilherme, Caio Almeida, Vinícius e Kilber
**Tecnologias:** MySQL 9.7 · Python · brModelo · GitHub Codespaces

## Estrutura

```
docs/modelos/   modelos conceitual e lógico
sql/parte_1/    01 base · 02 tabelas (modelo físico) · 03 dados de teste · 04 CRUD
sql/parte_2/    objetos da Parte 2
src/            main.py (menu) · banco.py (conexão) · crud.py (operações)
tests/          test_webdriver.py
```

## Como executar (Codespace)

```bash
# 1. Credenciais (defina DB_PASSWORD no .env)
cp .env.example .env
set -a; source .env; set +a

# 2. MySQL em contêiner
docker run -d --name webdriver-mysql -e MYSQL_ROOT_PASSWORD="$DB_PASSWORD" -p 3306:3306 mysql:9.7
until docker logs webdriver-mysql 2>&1 | grep -q "port: 3306"; do sleep 2; done

# 3. Scripts da Parte 1
for f in sql/parte_1/0{1,2,3}_*.sql; do
  docker exec -i -e MYSQL_PWD="$DB_PASSWORD" webdriver-mysql mysql -uroot < "$f"
done

# 4. Aplicação e testes
pip install -r requirements.txt
python src/main.py
pytest -v
```

O `04_consultas_crud.sql` demonstra o CRUD em SQL e altera os dados; para recomeçar, rode de novo o `02` e o `03`.

## Credenciais fictícias de teste

Somente para teste. Os scripts guardam apenas o hash das senhas.

| Login | Senha fictícia |
|---|---|
| `ana.souza` | `Teste@01Webdriver` |
| `bruno.lima` | `Teste@02Webdriver` |
| `carla.mendes` | `Teste@03Webdriver` |
| `diego.alves` | `Teste@04Webdriver` |
| `elisa.rocha` | `Teste@05Webdriver` |
| `fabio.nunes` | `Teste@06Webdriver` |
| `gabriela.costa` | `Teste@07Webdriver` |
| `henrique.dias` | `Teste@08Webdriver` |
