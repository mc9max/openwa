# syntax=docker/dockerfile:1
# ============================================================================
# Railway Template: OpenWA (rmyndharis/OpenWA)
# ----------------------------------------------------------------------------
# Open-source WhatsApp API gateway: NestJS backend + React dashboard bundled
# into one image, port 2785, SQLite by default, volume at /app/data.
#
# Base image already ships: the gosu entrypoint (chowns /app/data to the
# non-root `openwa` user on every start), the bundled React dashboard,
# Puppeteer/Chromium for the whatsapp-web.js engine, ffmpeg, and the /api/*
# REST surface with the React dashboard served by the same NestJS process.
#
# We add only a HEALTHCHECK (the image does not define one) using the exact
# route the upstream's own docker-compose.yml uses:
#   curl -f http://localhost:2785/api/health/ready
# (see src/modules/health/health.controller.ts: @Controller('health') plus the
# global 'api' prefix in configure-app.ts — verified against the app's own
# compose file healthcheck.test.)
# ============================================================================
ARG OPENWA_TAG=latest
FROM rmyndharis/openwa:${OPENWA_TAG}

ENV PORT=2785

EXPOSE 2785

HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=4 \
  CMD curl -fsS http://127.0.0.1:${PORT:-2785}/api/health/ready || exit 1
