#serve-backend.sh

echo "Sirviendo Backend..."
cd backend

echo "Activando Venv"
source parkingvenv/bin/activate

echo "Desactivado PYTHONPATH"
unset PYTHONPATH

echo "Iniciando Django..."
python manage.py runserver 0.0.0.0:8484