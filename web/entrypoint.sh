#!/bin/bash
set -e

echo "Waiting for database to be ready..."
for i in {1..30}; do
    if PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT 1;" > /dev/null 2>&1; then
        echo "Database is ready!"
        break
    fi
    echo "Waiting for database... ($i)"
    sleep 2
done

echo "Applying database migrations..."
python3 manage.py migrate --noinput

echo "Starting Django..."
exec python3 manage.py runserver 0.0.0.0:8000
