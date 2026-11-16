# Webdriver — Projeto de Banco de Dados (UNICAP)

O **Webdriver** é um sistema de armazenamento e compartilhamento de arquivos voltado para instituições de causa social. Cada usuário pode carregar, atualizar, remover, compartilhar e comentar arquivos. Toda operação fica registrada com data e hora, e cada alteração gera uma nova versão no histórico do arquivo. As instituições aderem a planos que definem o espaço disponível por usuário, e administradores atendem às solicitações de suporte.

O banco de dados foi modelado no **brModelo** e implementado em **MySQL**. A aplicação, em **Python**, oferece um menu no terminal para operar o sistema.

**Equipe:** Caio Vilela, Guilherme, Caio Almeida, Vinícius e Kilber

## O que o projeto entrega

**Parte 1 — Modelagem e CRUD**
- Modelos conceitual e lógico (`docs/modelos/`) e modelo físico (`sql/parte_1/02_create_tables.sql`).
- Inserir, buscar, atualizar e remover, em SQL (`sql/parte_1/04_consultas_crud.sql`) e pela aplicação Python (`src/`).
- Senhas guardadas apenas como hash (bcrypt) e credenciais do banco fora do código (`.env`).

**Parte 2 — Recursos do MySQL** (`sql/parte_2/`)
- Tabela `atividades_recentes`, acessível somente pelo root.
- Visões sem ids: do usuário, do histórico, da empresa e dos administradores.
- Roles `PapelUsuario`, `PapelEmpresa` e `PapelAdm`.
- Procedures `verificar_atividades`, `conta_usuarios`, `chavear` e `remover_acessos`, e a função `mais_de_100_dias`.
- Triggers `safe_security` (bloqueia executáveis), `registrar_operacao`, `atualizar_acesso` e limite de espaço por usuário.

## Como iniciar

No terminal do Codespace, na pasta do projeto:

**1. Carregar as credenciais do banco**

```bash
set -a; source .env; set +a
```

**2. Ligar o MySQL**

```bash
docker start webdriver-mysql
until docker exec webdriver-mysql mysqladmin ping --silent 2>/dev/null; do sleep 2; done
```

**3. Montar o banco de dados (Parte 1 e Parte 2)**

```bash
for f in sql/parte_1/0{1,2,3}_*.sql sql/parte_2/0{1,2,3,4,5}_*.sql; do
  echo ">> $f"
  docker exec -i -e MYSQL_PWD="$DB_PASSWORD" webdriver-mysql mysql -uroot < "$f" || break
done
```

Deve aparecer uma linha `>>` para cada um dos 8 scripts, sem `ERROR`. Para voltar ao estado inicial a qualquer momento, repita este passo.

**4. Abrir a aplicação**

```bash
python src/main.py
```

No menu, comece pela opção **1** e informe um login (por exemplo, `ana.souza`). Os arquivos são escolhidos pelo número da lista.

## Testes

```bash
# Aplicação Python: esperado "13 passed"
pytest -v

# Parte 2: esperado "OK 52" na tabela final
docker exec -i -e MYSQL_PWD="$DB_PASSWORD" webdriver-mysql mysql -uroot --table webdriver < sql/parte_2/06_testes.sql
```

## Contas de teste

Os dados são fictícios. A senha de cada login segue o padrão `Teste@NNWebdriver`, onde NN é o número do usuário: por exemplo, `ana.souza` (PapelUsuario e PapelEmpresa) = `Teste@01Webdriver` e `elisa.rocha` (PapelAdm) = `Teste@05Webdriver`. Para entrar no MySQL com uma dessas contas:

```bash
docker exec -it webdriver-mysql mysql -u ana.souza -p webdriver
```