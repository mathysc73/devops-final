name: CI/CD — FPS Tracker

on:
  push:
    branches: ["main", "develop"]
  pull_request:
    branches: ["main"]

env:
  IMAGE_NAME: fps-tracker

jobs:

  # ── 1. Lint ────────────────────────────────────────────────────────────
  lint:
    name: Lint (flake8)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Installer flake8
        run: pip install flake8

      - name: Lancer flake8
        run: |
          flake8 app/ --count --select=E9,F63,F7,F82 --show-source --statistics
          flake8 app/ --count --exit-zero --max-line-length=120 --statistics

  # ── 2. Tests ───────────────────────────────────────────────────────────
  test:
    name: Tests (pytest)
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Installer les dépendances
        run: pip install -r app/requirements.txt

      - name: Lancer pytest
        run: pytest app/tests/ -v --tb=short

  # ── 3. Build Docker ────────────────────────────────────────────────────
  build:
    name: Build & Smoke test
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - name: Build de l'image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: ${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Smoke test — vérifier que le conteneur démarre
        run: |
          docker run -d --name smoke -p 5000:5000 ${{ env.IMAGE_NAME }}:latest
          sleep 10
          curl --fail http://localhost:5000/health || (docker logs smoke && exit 1)
          curl --fail http://localhost:5000/api/leaderboard
          echo "Smoke test réussi ✓"
          docker stop smoke

  # ── 4. Push Docker Hub (main uniquement) ──────────────────────────────
  push:
    name: Push Docker Hub
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Métadonnées (tags)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=sha-
            type=raw,value=latest

      - name: Build et push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
