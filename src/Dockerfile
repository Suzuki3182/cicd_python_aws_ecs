FROM python:3.12-slim AS base

# Security: run as non-root
RUN groupadd --gid 1001 app && \
    useradd --uid 1001 --gid app --shell /bin/bash --create-home app

WORKDIR /app

# Install dependencies first (layer cache)
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY app/ .

# Remove write permissions from app code
RUN chmod -R a-w /app && chown -R app:app /app

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

ENTRYPOINT ["/app/entrypoint.sh"]
