FROM python:3.12-slim

WORKDIR /app

# Install deps first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY . .

# Run as non-root
RUN useradd -m -u 1001 agent-watch
USER agent-watch

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000"]
