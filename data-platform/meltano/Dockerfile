FROM meltano/meltano:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER meltano

WORKDIR /meltano/project

# Copy project files and install dependencies
COPY --chown=meltano:meltano . ./

# Ensure pip is up to date
RUN pip install --no-cache-dir --upgrade pip

# Install the project and custom tap
RUN pip install --no-cache-dir -e extractors/tap_hr_api
RUN meltano install

ENTRYPOINT ["meltano"]
CMD ["--help"]
