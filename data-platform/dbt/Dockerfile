# Standalone image for running dbt outside of Airflow (e.g. local `docker run` for ad-hoc
# `dbt run`/`dbt test`/`dbt docs generate`). The Airflow container also has dbt installed (see
# ../airflow/requirements.txt) and is what actually runs it in the scheduled pipeline - this image
# is for manual/CI use.
FROM python:3.12.7-slim

WORKDIR /dbt

RUN pip install --no-cache-dir dbt-core==1.8.8 dbt-snowflake==1.8.4

COPY . .

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin dbtuser \
    && chown -R dbtuser:dbtuser /dbt
USER dbtuser

# profiles.yml is expected to be volume-mounted at runtime (contains env-var references only, see
# profiles.yml.example) - never baked into the image.
ENTRYPOINT ["dbt"]
CMD ["--help"]
