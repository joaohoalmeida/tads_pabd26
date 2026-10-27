## Questão 1: Cadastro de Cliente e Perfil

**Cenário:** Um novo cliente deseja se cadastrar no sistema. Para isso, ele precisa inserir seus dados básicos e um endereço de contato.

**Tarefas:**

1. Inicie uma transação para inserir um novo registro na tabela `customer`.
2. Tente inserir um dado obrigatório que viole uma regra.
3. Observe a falha do comando.
4. Execute ROLLBACK.


``` sql
begin;

insert into customer (store_id, first_name, last_name, email, address_id, activebool, create_date, last_update, active)
values (1, 'João', 'Heli', 'joaoheli99@gmail.com', 1, 0, now(), now(), true);

commit;
```

O cliente cadastrado no passo 1 ainda existe na tabela? Por que o banco de dados deve "esquecer" todo o processo se um detalhe do cadastro falhar?

O erro que deu ao tentar executar o comando:

```
ERROR:  column "activebool" is of type boolean but expression is of type integer
LINE 2: ...es (1, 'João', 'Heli', 'joaoheli99@gmail.com', 1, 0, now(), ...
```

Violação ao tentar inserir um valor númerico em um atributo booleano, o banco deve esquecer o comando errado para preservar a integridade dos dados e impedir que um dado errado seja inserido.

## Questão 2: Gestão de Estoque e Suprimentos

**Cenário:** O gestor do estoque quer registrar a chegada de novos filmes e atualizar o status de disponibilidade.

**Tarefas:**

1. Inicie uma transação para inserir um novo registro na tabela `inventory`.
2. Execute um SAVEPOINT chamado *estoque_atualizado*.
3. Tente inserir uma entrada de inventário para um filme que não existe.
4. O comando falhará, mas você deve manter a inserção anterior.
5. Insira um registro de inventário válido e finalize com COMMIT.

```sql

begin;

insert into inventory (film_id, store_id, last_update)
values (1, 1, now());

savepoint estoque_atualizado

insert into inventory (film_id, store_id, last_update)
values (9999999, 1, now());

rollback to estoque_atualizado;

commit;
```

Após o COMMIT, a tabela possui apenas o registro válido ou ambos? Qual é a vantagem de usar SAVEPOINT aqui em vez de desistir de todo o processo de atualização do estoque?


Apenas o registro válido, a vantagem de usar savepoint é de não perder o progresso durante operações DML quando ocorre algum erro.


## Questão 3: Concorrência na Gestão de Estoque e Suprimentos

**Cenário:** Na operação logística da locadora, dois gestores de suprimentos estão tentando processar o mesmo item físico de estoque (mesmo `inventory_id`) exatamente ao mesmo tempo. Um gestor está tentando transferir a unidade recém cadastrada para a outra loja para suprir uma demanda, enquanto o outro está tentando excluí-la pois afirma ter que devolver ao distribuidor devido a um erro na emissão da nota fiscal de aquisição.

Simule uma transação concorrente para mostrar em sessões diferentes as ações de cada gestor. O que iniciar primeiro a transação terá prioridade. Mostre um passo-a-passo considerando se a sessão A iniciar primeiro e outro considerando a sessão B.