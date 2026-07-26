# Pin the exact patch version, not just "3.12" or "slim", so rebuilds are reproducible.
# Resolve and pin the digest (docker inspect --format='{{index .RepoDigests 0}}') from your
# Artifactory mirror before promoting this to a real environment - not fabricated here.
FROM python:3.12.7-slim

WORKDIR /app

COPY requirements.txt .
# --index-url should point at SSI JFrog Artifactory in CI/build environments, not public PyPI
# (set via PIP_INDEX_URL env at build time: docker build --build-arg PIP_INDEX_URL=...).
ARG PIP_INDEX_URL
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

# Non-root: create an unprivileged user and drop to it before running the app.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/employees')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
