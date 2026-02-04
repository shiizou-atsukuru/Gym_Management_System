import psycopg2
import os

# Connect using the service name 'db'
conn = psycopg2.connect(
    host="db",
    database="GYM_MANAGEMENT_SYSTEM",
    user="root",
    password="hello"
)
print("Successfully connected to the database!")