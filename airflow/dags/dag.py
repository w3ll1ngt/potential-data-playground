from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.mysql.hooks.mysql import MySqlHook
from airflow.operators.python import PythonOperator
from datetime import datetime

def transfer_data():
    # Создаем хуки для PostgreSQL и MySQL
    postgres_hook = PostgresHook(postgres_conn_id='postgres_conn')
    mysql_hook = MySqlHook(mysql_conn_id='mysql_conn')

    # Получаем список всех таблиц в PostgreSQL
    pg_conn = postgres_hook.get_conn()
    cursor = pg_conn.cursor()
    cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public';")
    tables = cursor.fetchall()

    for table in tables:
        table_name = table[0]
        # Выполняем SELECT запрос к каждой таблице PostgreSQL
        postgres_query = f"SELECT * FROM {table_name};"
        cursor.execute(postgres_query)
        rows = cursor.fetchall()

        # Получаем список колонок для текущей таблицы
        cursor.execute(f"SELECT column_name FROM information_schema.columns WHERE table_name='{table_name}';")
        columns = cursor.fetchall()
        column_names = [col[0] for col in columns]
        columns_str = ", ".join(column_names)
        placeholders = ", ".join(["%s"] * len(column_names))

        # Перенос данных в MySQL
        mysql_query = f"INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders})"
        mysql_conn = mysql_hook.get_conn()
        mysql_cursor = mysql_conn.cursor()
        mysql_cursor.executemany(mysql_query, rows)
        mysql_conn.commit()
        mysql_cursor.close()

    cursor.close()
    pg_conn.close()
    mysql_conn.close()

with DAG(
    'postgres_to_mysql_dag',
    start_date=datetime(2023, 1, 1),
    schedule_interval=None,  # Запуск вручную
    catchup=False,
) as dag:
    transfer_task = PythonOperator(
        task_id='transfer_data_task',
        python_callable=transfer_data,
    )