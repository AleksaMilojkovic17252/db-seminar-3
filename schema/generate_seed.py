#!/usr/bin/env python3
"""
Generate identical Phase 2 seed data for all three engines from a single
deterministic pass (fixed RNG seed), emitted in each engine's dialect:

  schema/seed_mysql.sql    -> load into TiDB       with `mysql`
  schema/seed_pg.sql       -> load into CockroachDB with `cockroach sql -f`
  schema/seed_spanner.sql  -> load into Spanner Omni one line/batch at a
                               time via the CLI (no bulk-file support there)

Row counts (must match across all three engines):
  accounts     50,000
  customers    20,000
  products      5,000
  orders       50,000
  order_items 120,000
  doctors          10   (ids 1 and 2 on_call = true, rest false)

IDs are assigned explicitly (not left to AUTO_INCREMENT/IDENTITY) on every
engine, including TiDB/CockroachDB, so the same row on all three engines
shares the same id -- Spanner has no autoincrement, so this is the only way
to keep the business data identical rather than just the row counts.

Column-name note for order_items: TiDB/CockroachDB use (id, order_id, ...)
where id is a meaningless surrogate key. Spanner's interleaved table (see
schema_googlesql.sql) requires its leading PK column to be literally named
`id` and share the parent's value, so Spanner's order_items uses
(id, item_id, ...) where id IS the parent order's id and item_id is the
item's own local sequence number within that order. This script accounts
for that mapping when generating each dialect's file.

Usage:
    python3 schema/generate_seed.py
"""
import random

SEED = 42
BATCH_SIZE = 1000

REGIONS = ["eu-west", "us-east", "us-west"]
CATEGORIES = ["Electronics", "Books", "Home", "Sports", "Toys", "Clothing", "Grocery", "Beauty"]

N_ACCOUNTS = 50_000
N_CUSTOMERS = 20_000
N_PRODUCTS = 5_000
N_ORDERS = 50_000


def generate():
    rng = random.Random(SEED)

    accounts = [
        {"id": i, "owner": f"Owner_{i:06d}", "balance": round(rng.uniform(100, 100000), 2),
         "region": rng.choice(REGIONS)}
        for i in range(1, N_ACCOUNTS + 1)
    ]

    customers = [
        {"id": i, "name": f"Customer_{i:06d}", "email": f"customer{i:06d}@example.com",
         "region": rng.choice(REGIONS)}
        for i in range(1, N_CUSTOMERS + 1)
    ]

    products = [
        {"id": i, "name": f"Product_{i:06d}", "category": rng.choice(CATEGORIES),
         "price": round(rng.uniform(5, 500), 2), "rating": round(rng.uniform(1, 5), 1)}
        for i in range(1, N_PRODUCTS + 1)
    ]

    orders = [
        {"id": i, "customer_id": rng.randint(1, N_CUSTOMERS), "total": round(rng.uniform(10, 2000), 2)}
        for i in range(1, N_ORDERS + 1)
    ]

    # 30,000 orders get 2 items, 20,000 orders get 3 items -> exactly 120,000 rows
    order_ids = list(range(1, N_ORDERS + 1))
    rng.shuffle(order_ids)
    two_item_orders = set(order_ids[:30_000])
    order_items = []
    surrogate_id = 1  # global surrogate id, used only by TiDB/CockroachDB
    for oid in range(1, N_ORDERS + 1):
        k = 2 if oid in two_item_orders else 3
        for item_seq in range(1, k + 1):
            order_items.append({
                "surrogate_id": surrogate_id, "order_id": oid, "item_id": item_seq,
                "product_id": rng.randint(1, N_PRODUCTS),
                "quantity": rng.randint(1, 5),
                "unit_price": round(rng.uniform(5, 500), 2),
            })
            surrogate_id += 1
    assert len(order_items) == 120_000

    doctors = [
        {"id": i, "name": f"Doctor_{i:02d}", "on_call": i in (1, 2)}
        for i in range(1, 11)
    ]

    return accounts, customers, products, orders, order_items, doctors


def batches(rows, size=BATCH_SIZE):
    for i in range(0, len(rows), size):
        yield rows[i:i + size]


def write_sql_file(path, statements_iter):
    with open(path, "w") as f:
        for stmt in statements_iter:
            f.write(stmt)
            f.write("\n")


# ---------------------------------------------------------------- MySQL/TiDB

def emit_mysql(accounts, customers, products, orders, order_items, doctors):
    def stmts():
        for b in batches(accounts):
            vals = ",".join(f"({r['id']}, '{r['owner']}', {r['balance']}, '{r['region']}')" for r in b)
            yield f"INSERT INTO accounts (id, owner, balance, region) VALUES {vals};"
        for b in batches(customers):
            vals = ",".join(f"({r['id']}, '{r['name']}', '{r['email']}', '{r['region']}')" for r in b)
            yield f"INSERT INTO customers (id, name, email, region) VALUES {vals};"
        for b in batches(products):
            vals = ",".join(f"({r['id']}, '{r['name']}', '{r['category']}', {r['price']}, {r['rating']})" for r in b)
            yield f"INSERT INTO products (id, name, category, price, rating) VALUES {vals};"
        for b in batches(orders):
            vals = ",".join(f"({r['id']}, {r['customer_id']}, {r['total']})" for r in b)
            yield f"INSERT INTO orders (id, customer_id, total) VALUES {vals};"
        for b in batches(order_items):
            vals = ",".join(
                f"({r['surrogate_id']}, {r['order_id']}, {r['product_id']}, {r['quantity']}, {r['unit_price']})"
                for r in b
            )
            yield f"INSERT INTO order_items (id, order_id, product_id, quantity, unit_price) VALUES {vals};"
        vals = ",".join(f"({r['id']}, '{r['name']}', {1 if r['on_call'] else 0})" for r in doctors)
        yield f"INSERT INTO doctors (id, name, on_call) VALUES {vals};"

    write_sql_file("schema/seed_mysql.sql", stmts())


# ------------------------------------------------------------- Postgres/CRDB

def emit_pg(accounts, customers, products, orders, order_items, doctors):
    def stmts():
        for b in batches(accounts):
            vals = ",".join(f"({r['id']}, '{r['owner']}', {r['balance']}, '{r['region']}')" for r in b)
            yield f"INSERT INTO accounts (id, owner, balance, region) VALUES {vals};"
        for b in batches(customers):
            vals = ",".join(f"({r['id']}, '{r['name']}', '{r['email']}', '{r['region']}')" for r in b)
            yield f"INSERT INTO customers (id, name, email, region) VALUES {vals};"
        for b in batches(products):
            vals = ",".join(f"({r['id']}, '{r['name']}', '{r['category']}', {r['price']}, {r['rating']})" for r in b)
            yield f"INSERT INTO products (id, name, category, price, rating) VALUES {vals};"
        for b in batches(orders):
            vals = ",".join(f"({r['id']}, {r['customer_id']}, {r['total']})" for r in b)
            yield f"INSERT INTO orders (id, customer_id, total) VALUES {vals};"
        for b in batches(order_items):
            vals = ",".join(
                f"({r['surrogate_id']}, {r['order_id']}, {r['product_id']}, {r['quantity']}, {r['unit_price']})"
                for r in b
            )
            yield f"INSERT INTO order_items (id, order_id, product_id, quantity, unit_price) VALUES {vals};"
        vals = ",".join(f"({r['id']}, '{r['name']}', {str(r['on_call']).lower()})" for r in doctors)
        yield f"INSERT INTO doctors (id, name, on_call) VALUES {vals};"

    write_sql_file("schema/seed_pg.sql", stmts())


# ---------------------------------------------------------------- Spanner Omni
# One statement per line, no trailing semicolons (the CLI's --sql takes a
# single bare statement). A companion loader script feeds this file to
# `docker exec ... execute-sql` one line/batch at a time.

def emit_spanner(accounts, customers, products, orders, order_items, doctors):
    def stmts():
        for b in batches(accounts):
            vals = ",".join(f"({r['id']}, '{r['owner']}', {r['balance']}, '{r['region']}')" for r in b)
            yield f"INSERT INTO accounts (id, owner, balance, region) VALUES {vals}"
        for b in batches(customers):
            vals = ",".join(
                f"({r['id']}, '{r['name']}', '{r['email']}', '{r['region']}', PENDING_COMMIT_TIMESTAMP())"
                for r in b
            )
            yield f"INSERT INTO customers (id, name, email, region, created_at) VALUES {vals}"
        for b in batches(products):
            vals = ",".join(f"({r['id']}, '{r['name']}', '{r['category']}', {r['price']}, {r['rating']})" for r in b)
            yield f"INSERT INTO products (id, name, category, price, rating) VALUES {vals}"
        for b in batches(orders):
            vals = ",".join(f"({r['id']}, {r['customer_id']}, PENDING_COMMIT_TIMESTAMP(), {r['total']})" for r in b)
            yield f"INSERT INTO orders (id, customer_id, order_date, total) VALUES {vals}"
        for b in batches(order_items):
            vals = ",".join(
                f"({r['order_id']}, {r['item_id']}, {r['product_id']}, {r['quantity']}, {r['unit_price']})"
                for r in b
            )
            yield f"INSERT INTO order_items (id, item_id, product_id, quantity, unit_price) VALUES {vals}"
        vals = ",".join(f"({r['id']}, '{r['name']}', {str(r['on_call']).lower()})" for r in doctors)
        yield f"INSERT INTO doctors (id, name, on_call) VALUES {vals}"

    write_sql_file("schema/seed_spanner.sql", stmts())


def main():
    accounts, customers, products, orders, order_items, doctors = generate()
    emit_mysql(accounts, customers, products, orders, order_items, doctors)
    emit_pg(accounts, customers, products, orders, order_items, doctors)
    emit_spanner(accounts, customers, products, orders, order_items, doctors)
    print("Wrote schema/seed_mysql.sql, schema/seed_pg.sql, schema/seed_spanner.sql")


if __name__ == "__main__":
    main()
