# LISTA DE EXERCÍCIOS 2 - Views, Indexes e Triggers

## Orientações gerais

A base `dvdrental` representa uma locadora e contém 15 tabelas, incluindo `film`, `inventory`, `rental`, `payment`, `customer`, `staff`, `store`, `category` e tabelas associativas.

Lembre-se de validar todas as questões, realizando as devidas consultas.

---

## Questão 01 - View de Performance da Equipe

A gerência quer um painel rápido para avaliar o desempenho dos funcionários. Crie uma view chamada `v_staff_performance` que exiba:

- `staff_id` e o nome completo do funcionário;
- endereço (cidade + país) onde a loja dele está localizada;
- A quantidade total de locações (`rentals`) processadas por ele;
- O valor total arrecadado através dos pagamentos que ele registrou.

*Dica*: Use LEFT JOIN para não excluir funcionários recém-contratados que ainda não processaram locações, e COALESCE para tratar nulos como zero.

---

## Questão 02 - View Materializada de Receita por Categoria

O relatório de receita por categoria de filme é muito pesado, pois exige cruzar `category`, `film_category`, `inventory`, `rental` e `payment`. Crie uma Materialized View chamada `mv_category_total_sales` que liste o nome da categoria e o total de receita gerado por ela. Crie um índice único na MV que permita que ela seja atualizada de forma não-bloqueante (CONCURRENTLY). Escreva o comando SQL para recarregar os dados da MV sem bloquear as consultas dos usuários do sistema.

---

## Questão 03 - Otimizando Filmes Atrasados

O sistema de cobrança roda a cada hora buscando locações que ainda não foram devolvidas (`return_date IS NULL`) para calcular multas. Como a tabela `rental` é grande e a maioria dos filmes já foi devolvida, um *Seq Scan* é muito caro. Crie um índice (parcial?) na tabela `rental` que indexe apenas as locações em aberto. Em seguida, escreva a consulta e use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

---

## Questão 04 - Busca Inteligente de Sinopses

Os clientes reclamam que a busca por palavras-chave na descrição dos filmes (`description`) usando `LIKE '%palavra%'` está lenta e não encontra variações da palavra (ex: "act", "acting", "actor"). Crie um índice adequado para melhorar o desempenho na busca. Em seguida, escreva uma consulta par buscar *documentary* e *drama* na descrição. Use o `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

---

## Questão 05 - Histórico do Cliente

Sempre que o cliente abre seu perfil no aplicativo, o sistema busca o histórico de pagamentos dele, ordenados do mais recente para o mais antigo:

`SELECT * FROM payment WHERE customer_id = X ORDER BY payment_date DESC`.

Para otimizar essa consulta específica, crie um índice multicoluna na tabela `payment`. Qual coluna deve vir primeiro no índice e por quê?

---

## Questão 06 - Login Case-Insensitive

O suporte técnico frequentemente busca clientes pelo e-mail, mas os atendentes não se preocupam com letras maiúsculas ou minúsculas (ex: buscam por `MARY.SMITH@...` quando o e-mail está gravado como `mary.smith@...`). Crie um **Índice Funcional** (Expression Index) na tabela `customer` que permita buscas rápidas e *case-insensitive* na coluna `email`. Crie uma consulta usando `EXPLAIN ANALYZE` para provar que o índice está sendo utilizado.

---

## Questão 07 - Validação de Datas

Ocorreu um bug no front-end que permitiu inserir locações onde a data de devolução (`return_date`) era *anterior* à data de locação (`rental_date`), gerando multas negativas. Crie um trigger `BEFORE INSERT OR UPDATE` na tabela `rental` que lance uma exceção (`RAISE EXCEPTION`) caso o `NEW.return_date` seja menor que o `NEW.rental_date`. Lembre-se de tratar o caso onde o `return_date` é `NULL` (o filme ainda está com o cliente). Realize 2 consultas teste para validar (sucesso/falha);

---

## Questão 08 - Auditoria de Preços

A administração suspeita que gerentes de loja estão alterando o custo de substituição (`replacement_cost`) de filmes raros sem autorização. Crie uma tabela de auditoria chamada `film_cost_audit` (`film_id`, `old_cost`, `new_cost`, `changed_at`) e uma trigger `AFTER UPDATE` na tabela `film` que insira um registro nessa tabela **apenas** se o `replacement_cost` for efetivamente modificado (utilize a cláusula `WHEN` na criação da trigger).

---

## Questão 09 - Proteção de Catálogo

Para evitar "buracos" no catálogo e erros de chave estrangeira órfã, o banco de dados não deve permitir a exclusão de um idioma da tabela `language` caso existam filmes cadastrados que o utilizem (seja como idioma original ou de áudio). Crie uma trigger `BEFORE DELETE` na tabela `language` que verifique as tabelas `film` (`language_id` e `original_language_id`). Se houver filmes vinculados, a exclusão deve ser abortada com uma mensagem de erro amigável.

---

## Questão 10 - Sincronização de Estatísticas

Para evitar contar as linhas da tabela `rental` toda vez que quisermos saber quantos filmes um cliente já alugou, vamos manter uma tabela de estatísticas.

- Crie a tabela `customer_rental_stats` (`customer_id` PK, `total_rentals` INT DEFAULT 0).
- Popule-a inicialmente com os dados atuais.
- Crie uma trigger `AFTER INSERT` na tabela `rental` que, a cada nova locação, atualize (incremento `+1`) o contador do respectivo cliente na tabela de estatísticas (verifique a existência).

## RESOLUÇÃO DA LISTA

questão 1:

```sql
create or replace view v_staff_performance as
select 
    s.staff_id,
    s.first_name || ' ' || s.last_name as full_name,
    c.city || ', ' || co.country as address_location,
    count(r.rental_id) as total_rentals,
    coalesce(sum(p.amount), 0) as total_amount
from staff s
join address a on s.address_id = a.address_id
join city c on a.city_id = c.city_id
join country co on c.country_id = co.country_id
left join rental r on s.staff_id = r.staff_id
left join payment p on r.rental_id = p.rental_id
group by s.staff_id, s.first_name, s.last_name, c.city, co.country;
```

questão 2:

```sql
create materialized view mv_category_total_sales as
select 
    c.name as category_name,
    sum(p.amount) as total_sales
from category c
join film_category fc on c.category_id = fc.category_id
join inventory i on fc.film_id = i.film_id
join rental r on i.inventory_id = r.inventory_id
join payment p on r.rental_id = p.rental_id
group by c.name;

create unique index idx_mv_category_name on mv_category_total_sales(category_name);

refresh materialized view concurrently mv_category_total_sales;
```

questão 3:

```sql
create index idx_rental_not_returned on rental(rental_id) where return_date is null;

explain analyze 
select * from rental where return_date is null;
```

questão 4:

```sql
create index idx_film_desc_fts on film using gin (to_tsvector('english', description));

explain analyze 
select title, description 
from film 
where to_tsvector('english', description) @@ to_tsquery('english', 'documentary & drama');
```

questão 5:

```sql
create index idx_payment_cust_date on payment(customer_id, payment_date desc);
```

questão 6:

```sql
create index idx_customer_email_lower on customer(lower(email));

explain analyze 
select * from customer where lower(email) = 'mary.smith@sakilacustomer.org';
```

questão 7:

```sql
create or replace function check_rental_dates()
returns trigger as $$
begin
    if new.return_date is not null and new.return_date < new.rental_date then
        raise exception 'a data de devolução não pode ser menor que a data de locação.';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_validate_rental_dates
before insert or update on rental
for each row
execute function check_rental_dates();

insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id) 
values ('2023-10-01', 1, 1, '2023-10-05', 1);

insert into rental (rental_date, inventory_id, customer_id, return_date, staff_id) 
values ('2023-10-05', 1, 1, '2023-10-01', 1);
```

questão 8:

```sql
create table film_cost_audit (
    film_id int,
    old_cost numeric,
    new_cost numeric,
    changed_at timestamp default current_timestamp
);

create or replace function audit_film_replacement_cost()
returns trigger as $$
begin
    insert into film_cost_audit (film_id, old_cost, new_cost)
    values (new.film_id, old.replacement_cost, new.replacement_cost);
    return new;
end;
$$ language plpgsql;

create trigger trg_audit_cost
after update on film
for each row
when (old.replacement_cost is distinct from new.replacement_cost)
execute function audit_film_replacement_cost();
```

questão 9:

```sql
create or replace function prevent_language_deletion()
returns trigger as $$
begin
    if exists (
        select 1 from film 
        where language_id = old.language_id or original_language_id = old.language_id
    ) then
        raise exception 'exclusão bloqueada: existem filmes utilizando este idioma.';
    end if;
    return old;
end;
$$ language plpgsql;

create trigger trg_protect_language
before delete on language
for each row
execute function prevent_language_deletion();
```

questão 10:

```sql
create table customer_rental_stats (
    customer_id int primary key,
    total_rentals int default 0
);

insert into customer_rental_stats (customer_id, total_rentals)
select customer_id, count(rental_id)
from rental
group by customer_id;

create or replace function update_rental_stats()
returns trigger as $$
begin
    insert into customer_rental_stats (customer_id, total_rentals)
    values (new.customer_id, 1)
    on conflict (customer_id) 
    do update set total_rentals = customer_rental_stats.total_rentals + 1;
    
    return new;
end;
$$ language plpgsql;

create trigger trg_sync_rental_stats
after insert on rental
for each row
execute function update_rental_stats();
```

