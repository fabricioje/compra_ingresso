# Banco de dados PostgreSQL (Docker)

Este projeto usa um banco de dados PostgreSQL rodando dentro de um container Docker.
Um **container** é uma "caixinha" isolada onde o banco roda, sem precisar instalar nada direto no seu computador.

## Configuração do banco

Definida no `Dockerfile`:

| Item    | Valor       |
|---------|-------------|
| Versão  | PostgreSQL 18 (alpine) |
| Usuário | `postgres`  |
| Senha   | `postgres`  |
| Banco   | `ingressos` |
| Porta   | `5432`      |

> **Atenção:** a senha fica gravada na imagem. Isso é aceitável para estudo local.
> Se a imagem for para um lugar público ou para a nuvem, passe a senha ao rodar o container
> (`-e POSTGRES_PASSWORD=...`) em vez de deixá-la fixa no `Dockerfile`.

## Como subir o banco

1. Criar a imagem (o "molde" do container):

   ```bash
   docker build -t ingressos-postgres .
   ```

2. Rodar o container:

   ```bash
   docker run -d --name db -p 5432:5432 postgres 
   ```

   - `-d` roda em segundo plano.
   - `--name` dá um nome ao container.
   - `-p 5432:5432` abre a porta para você acessar o banco de fora do container.
     Sem isso, só é possível acessar por dentro dele (o `EXPOSE` do `Dockerfile` é só uma anotação e não abre a porta).

## Como saber se está tudo funcionando

### 1. Ver os logs (fora do container)

```bash
docker logs ingressos-db
```

Procure a frase `database system is ready to accept connections`. Ela indica que o banco iniciou corretamente.

### 2. Entrar no container

```bash
docker exec -it ingressos-db sh
```

### 3. Verificar se o banco aceita conexões

```bash
pg_isready
```

Resposta esperada:

```
/var/run/postgresql:5432 - accepting connections
```

(`accepting connections` = "aceitando conexões", ou seja, o banco está de pé.)

### 4. Entrar no banco

```bash
psql -U postgres -d ingressos
```

O `psql` é o programa de linha de comando do Postgres. O `-U` indica o usuário e o `-d` indica qual banco abrir.
Se der certo, o prompt muda para `ingressos=#`.

### 5. Comandos rápidos de conferência

Dentro do `psql`:

```sql
SELECT version();            -- mostra a versão (deve ser a 18)
SELECT current_database();   -- deve mostrar "ingressos"
\l                           -- lista todos os bancos
\conninfo                    -- mostra os dados da conexão atual
```

### 6. Teste de escrita e leitura

Para ter certeza de que o banco realmente guarda dados:

```sql
CREATE TABLE teste (id serial PRIMARY KEY, nome text);
INSERT INTO teste (nome) VALUES ('funcionando');
SELECT * FROM teste;
DROP TABLE teste;
```

Se o `SELECT` devolver a linha `funcionando`, está tudo certo.
O `DROP TABLE` apaga a tabela de teste no final.

Para sair do `psql`, digite `\q`.

### 7. Testar de fora do container (pelo seu computador)

```bash
psql -h localhost -p 5432 -U postgres -d ingressos
```

Só funciona se a porta foi publicada com `-p 5432:5432` ao rodar o container.

## Comandos úteis do dia a dia

```bash
docker stop ingressos-db     # para o container
docker start ingressos-db    # liga de novo
docker rm -f ingressos-db    # apaga o container
```

> **Importante:** ao apagar o container, os dados do banco também são perdidos,
> a menos que você use um **volume** (um espaço no seu computador onde o Docker guarda os dados de forma permanente).
> Para guardar os dados, rode com `-v ingressos-data:/var/lib/postgresql`:
>
> ```bash
> docker run -d --name ingressos-db -p 5432:5432 -v ingressos-data:/var/lib/postgresql ingressos-postgres
> ```
