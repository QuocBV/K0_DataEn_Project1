# Pin the exact Airflow + Python patch version for reproducible builds.
FROM apache/airflow:2.10.2-python3.12

# The official image already creates and runs as the unprivileged "airflow" user (uid 50000) -
# keep it that way, don't add USER root except transiently for OS package installs below.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow

COPY requirements.txt /requirements.txt
# --index-url should point at SSI JFrog Artifactory in CI/build environments, not public PyPI.
ARG PIP_INDEX_URL
RUN pip install --no-cache-dir --user -r /requirements.txt

COPY dags/ /opt/airflow/dags/

# dbt/ and scripts/ live one level up (data-platform/) so they're outside this Dockerfile's own
# directory - docker-compose.yml mounts them as volumes at container runtime instead of COPYing
# them here (see ../docker-compose.yml). For an image that must be fully self-contained (no
# volume mounts, e.g. a real prod deploy), rebuild with the build context set to data-platform/
# and this dockerfile referenced via -f airflow/Dockerfile, then add:
#   COPY dbt/ /opt/airflow/data-platform/dbt/
#   COPY scripts/ /opt/airflow/data-platform/scripts/
