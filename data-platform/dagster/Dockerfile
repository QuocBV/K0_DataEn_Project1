FROM python:3.12-slim
WORKDIR /opt/dagster
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["dagster-webserver", "-h", "0.0.0.0", "-p", "3000"]
