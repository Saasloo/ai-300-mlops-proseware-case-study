FROM python:3.13-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN uv pip install --system --no-cache \
    kagglehub==1.0.2 \
    pandas==3.0.5 \
    azure-ai-ml==1.34.1 \
    azure-identity==1.25.3
