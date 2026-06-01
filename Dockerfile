# ── Image de base légère ──────────────────────────────────────────────────
FROM python:3.12-slim

LABEL maintainer="groupe-devops"
LABEL description="FPS Tracker — Stats CS2, Valorant, Call of Duty"
LABEL version="1.0.0"

# Évite les fichiers .pyc et les buffers de sortie
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_ENV=production

WORKDIR /app

# ── Dépendances (couche mise en cache si requirements.txt inchangé) ───────
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Code applicatif ───────────────────────────────────────────────────────
COPY app/ .

# Utilisateur non-root (bonne pratique de sécurité)
RUN adduser --disabled-password --gecos '' tracker
USER tracker

EXPOSE 5000

# Healthcheck intégré au conteneur
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "app.py"]
