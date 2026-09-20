# Design: rotas e lógica de assentos (Seat)

Data: 2026-09-20
Status: aprovado para implementação

## Objetivo

Expor os assentos de um evento pela API e implementar o ciclo de vida da
reserva: reservar um assento para um usuário por tempo limitado, liberar
uma reserva e devolver ao acervo as reservas que expiraram.

## Contexto

A tabela `seats` já existe (migration `20260920165948_create_seats.rb`) com
`event_id`, `user_id` (opcional), `sector`, `row`, `number`, `price`,
`status` (enum `livre: 0, reservado: 1, vendido: 2`) e `reserved_until`.
O model hoje só declara associações e o enum.

Os controllers `UsersController` e `EventsController` estabelecem o padrão
da API: `ActionController::API`, `before_action :set_<recurso>`,
`params.expect`, um método privado `<recurso>_json` para serializar e
tratamento de `RecordNotFound` / `ParameterMissing` no `ApplicationController`.

Não existe autenticação no projeto: `User` tem `has_secure_password`, mas
não há sessão nem token.

## Decisões

1. **A lógica de transição mora no model `Seat`.** O projeto é pequeno e
   segue Rails omakase; um service object não se paga aqui. Quando o fluxo
   de compra existir, `Order` será o orquestrador e `Seat` continua dono
   das próprias transições.
2. **O usuário que reserva vem no corpo da requisição (`user_id`).**
   Solução de ponte, explicitamente insegura: sem autenticação qualquer
   cliente reserva em nome de qualquer usuário. Vira `current_user` quando
   houver autenticação.
3. **Expiração preguiçosa, com job de limpeza por cima.** Toda leitura e a
   própria reserva tratam `reserved_until` vencido como disponível — é isso
   que garante a correção. O job recorrente só faz higiene do banco; se
   atrasar ou não rodar, o comportamento da API não muda.
4. **Concorrência resolvida por trava de linha** (`with_lock`, ou seja
   `SELECT … FOR UPDATE`) dentro de `reserve!`. Sem isso dois pedidos
   simultâneos reservam o mesmo assento.

## Escopo

Incluído: CRUD de assentos, `reserve`, `release`, expiração automática,
testes de model, de requisição e do job.

Fora de escopo: criar `Order`/`OrderItem` a partir dos assentos e marcar
`vendido` (fluxo de compra); autenticação real.

## Rotas

```ruby
resources :events do
  resources :seats, shallow: true do
    member do
      post :reserve
      post :release
    end
  end
end
```

| Verbo | Rota | Ação | Notas |
|---|---|---|---|
| GET | `/events/:event_id/seats` | index | filtros opcionais `status` e `sector` |
| POST | `/events/:event_id/seats` | create | 201 |
| GET | `/seats/:id` | show | |
| PATCH/PUT | `/seats/:id` | update | |
| DELETE | `/seats/:id` | destroy | 422 se vendido ou com `order_items` |
| POST | `/seats/:id/reserve` | reserve | body `{"user_id": 1}` |
| POST | `/seats/:id/release` | release | |

`index` aceita `?status=livre` e `?sector=A`. Um `status` desconhecido
responde 422 em vez de estourar o enum. Sem filtro, retorna todos os
assentos do evento ordenados por `id`.

## Model `Seat`

```ruby
RESERVATION_TTL = 15.minutes
```

Validações:

- `number`: presente; único no escopo `event_id + sector + row`
- `price`: numérico `>= 0`, permitindo nulo
- `event`: obrigatório (via `belongs_to`)

Scopes:

- `expiradas`: `reservado` com `reserved_until` no passado
- `disponiveis`: `livre` **ou** `expiradas`

Métodos públicos:

- `disponivel?(at = Time.current)` — `livre?`, ou `reservado?` com
  `reserved_until` já vencido. Um `reservado` com `reserved_until` nulo
  **não** é disponível (reserva sem prazo não expira sozinha).
- `reserve!(user, ttl: RESERVATION_TTL)` — dentro de `with_lock`: recarrega
  o registro, aborta se não estiver disponível, senão grava
  `status: :reservado`, `user`, `reserved_until: ttl.from_now`. Retorna
  `true`/`false`; em caso de recusa adiciona a mensagem em `errors[:base]`.
- `release!` — dentro de `with_lock`: recusa se `vendido?`, senão volta a
  `status: :livre`, `user: nil`, `reserved_until: nil`. Mesma convenção de
  retorno. Liberar um assento já livre é idempotente (retorna `true`).

O nome com `!` segue a convenção de "grava no banco", não de "levanta
exceção"; ambos retornam booleano e não estouram em conflito de estado.

## Controller `SeatsController`

Segue o padrão de `UsersController`/`EventsController`.

- `set_seat` para `show/update/destroy/reserve/release`; `set_event` para
  `index/create` (via `params[:event_id]`).
- `seat_params`: `params.expect(seat: %i[sector row number price])`.
  `status`, `user_id` e `reserved_until` **não** são atribuíveis em massa:
  o estado do assento só muda por `reserve!`/`release!`. Permitir `status`
  no CRUD deixaria criar um `reservado` sem `reserved_until`, que pela
  regra de `disponivel?` travaria o assento para sempre.
- `seat_json`: `id, event_id, sector, row, number, price, status,
  reserved_until, user_id, created_at, updated_at`, mais o campo calculado
  `disponivel`.
- `reserve`: exige `user_id` (ausente → 400 via `ParameterMissing`);
  usuário inexistente → 404; assento indisponível → **409 Conflict** com
  `{"errors": …}`.
- `release`: assento vendido → 409.
- `update`: assento `vendido` é recusado com 422 — os dados de um assento já
  comprado (setor, fileira, número, preço) não mudam por baixo do comprador.
- `destroy`: se `destroy` falhar (`order_items` com
  `restrict_with_error`) → 422; assento `vendido` também é recusado com 422.

Códigos: 200/201 sucesso, 204 no destroy, 400 parâmetro ausente, 404 não
encontrado, 409 conflito de estado, 422 validação.

## Job de expiração

`ReleaseExpiredSeatsJob` percorre `Seat.expiradas` em lotes e chama
`release_if_expired!` em cada um. O `SELECT` que monta o lote roda fora de
qualquer trava, então a trava por linha (`with_lock`) sozinha só serializa o
acesso — não revalida nada. `release_if_expired!` reconfere dentro do
`with_lock` que a reserva continua vencida antes de liberar; se uma reserva
nova tiver sido feita entre a leitura do lote e a liberação, ela é
preservada. Registrado em `config/recurring.yml`, que hoje só tem bloco
`production` — em desenvolvimento e teste a limpeza é manual, e a
expiração preguiçosa cobre o comportamento.

## Testes

Model (`test/models/seat_test.rb`):

- reserva assento livre grava usuário, status e `reserved_until`
- reserva de assento já reservado (prazo válido) falha e preserva o dono
- reserva de assento com reserva expirada funciona e troca o dono
- reserva de assento vendido falha
- `release!` libera reservado; é idempotente em livre; recusa vendido
- unicidade de `number` por evento/setor/fileira

Requisição (`test/controllers/seats_controller_test.rb`): as sete rotas,
incluindo 409 no conflito de reserva, 400 sem `user_id`, filtros do index e
422 no destroy bloqueado.

Job (`test/jobs/release_expired_seats_job_test.rb`): libera vencido, não
toca em reserva válida nem em vendido.

As fixtures atuais de `seats` usam `status: 1` com `reserved_until` no
passado; serão ajustadas para cobrir os estados de propósito.

Os testes rodam no container: `docker compose exec -w /app/ingressos backend bin/rails test`.
