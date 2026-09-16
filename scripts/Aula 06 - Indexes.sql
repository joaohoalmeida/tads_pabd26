-- INDEXES
-- Exibe esquema, índices e definições
select
    schemaname,
    tablename,
    indexname,
    indexdef
from
    pg_indexes
where
    tablename = 'customer' -- Nome da tabela
order by
    tablename,
    indexname;

select
    address_id,
    address,
    district,
    phone
from
    address
where
    phone = '223664661973';

explain analyze
select
    address_id,
    address,
    district,
    phone
from
    address
where
    phone = '223664661973';

drop index if exists idx_address_phone;

-- Seq Scan on address  (cost=0.00..15.54 rows=1 width=45) (actual time=0.029..0.134 rows=1 loops=1)
--    Filter: ((phone)::text = '223664661973'::text)
--    Rows Removed by Filter: 602
--  Planning Time: 0.095 ms
--  Execution Time: 0.150 ms
create index idx_address_phone on address (phone);

-- Index Scan using idx_address_phone on address  (cost=0.28..8.29 rows=1 width=45) (actual time=0.023..0.025 rows=1 loops=1)
--    Index Cond: ((phone)::text = '223664661973'::text)
--  Planning Time: 0.081 ms
--  Execution Time: 0.040 ms
explain analyze
select
    customer_id,
    first_name,
    last_name
from
    customer
where
    last_name = 'Purdy';

drop index if exists idx_customer_last_name;

create index idx_customer_last_name_lower on customer (lower(last_name));

explain analyze
select
    customer_id,
    first_name,
    last_name
from
    customer
where
    lower(last_name) = 'purdy';

-- ÍNDICES PARCIAIS
-- A partial index is an index built on a SUBSET OF DATA of the indexed columns.
-- To define a subset of data, you use a predicate, which is a conditional expression, of the partial index. PostgreSQL will build an index for rows that satisfy the predicate.
-- Indexando buscar por clientes inativos (active=0)
drop index if exists idx_customer_active;

create index idx_customer_active on customer (active)
where
    active = 0;

explain analyze
select
    customer_id,
    active
from
    customer
where
    active = 0;

-- Predicado!
-- ÍNDICES MULTICOLUNAS
-- where
--     column1 = v1
--     AND column2 = v2
--     AND column3 = v3;
-- where
--     column1 = v1
--     AND column2 = v2;
-- where
--     column1 = v1;
-- Executar script: \i utils/script_index_fts.sql
drop index if exists idx_people_names;

create index idx_people_names on people (last_name, first_name);

explain analyze
select
    id,
    first_name,
    last_name
from
    people
where
    last_name = 'Adams'
    and first_name = 'Lou';

-- O planejador opta por não utilizar o índice
explain analyze
select
    id,
    first_name,
    last_name
from
    people
where
    first_name = 'Lou';

/* 
TO DO: CRIAÇÃO DE ÍNDICES - Esquema lista01

- Baseado nas views (comando \dmv), quais índices poderiam ser criados?
- Para forçar o uso dos índices em tabelas pequenas: SET enable_seqscan = off;
 */
-- Típos de índices
-- Hash
drop index if exists idx_customer_email_hash;

create index idx_customer_email_hash on customer using hash (email);

explain analyze
select
    first_name
from
    customer
where
    email = 'a@tads.ifrn';

-- GIN
select
    to_tsvector ('watches'),
    to_tsvector ('watched'),
    to_tsvector ('watching');

select
    to_tsvector ('The quick brown fox jumps over the lazy dog.');

select
    id,
    to_tsvector ('portuguese', body) body_search
from
    posts;

select
    id,
    to_tsvector ('portuguese', title || ' ' || body) search
from
    posts;

drop index if exists idx_posts_search_gin;

create index idx_posts_search_gin on posts using gin (to_tsvector ('portuguese', title || ' ' || body));

select
    id,
    title,
    body
from
    posts
where
    -- 1) Busca título e corpo que contenham as palavras 'postgresql' E 'recursos'
    -- to_tsvector ('portuguese', title || ' ' || body) @@ to_tsquery('portuguese', 'postgresql & recursos');
    -- 2) Busca título e corpo que contenham as palavras 'eficiente' OU 'recursos'
    -- to_tsvector ('portuguese', title || ' ' || body) @@ to_tsquery('portuguese', 'eficiente | recursos');
    -- 3) Busca título e corpo que contenha a frase "full-text search"
    -- to_tsvector ('portuguese', title || ' ' || body) @@ to_tsquery('portuguese', '''full-text search''');
    -- 4) Busca título e corpo que NÃO contenha a palavra 'eficiente'
    -- to_tsvector ('portuguese', title || ' ' || body) @@ to_tsquery('portuguese', '!eficiente');
    -- 5) Busca título e corpo por prefixo 'con'
    -- to_tsvector ('portuguese', title || ' ' || body) @@ to_tsquery('portuguese', 'con:*');

select
    id,
    title,
    body,
    ts_rank(
        setweight(to_tsvector('portuguese', title), 'A') ||
        setweight(to_tsvector('portuguese', body), 'B'),
        to_tsquery('portuguese', 'postgresql')
    ) rank
from posts
where (
    setweight(to_tsvector('portuguese', title), 'A') ||
    setweight(to_tsvector('portuguese', body), 'B')
    ) @@ to_tsquery('portuguese', 'postgresql')
order by rank desc;