#!/usr/bin/env bash
# Asks for the SQL Server (RDS) user and password and writes them into .env, so they never travel
# through a chat, a command history or git. Run it on every server that needs them (control, mongo).
# usage (needs a terminal):  bash set-db-credentials.sh
set -euo pipefail
cd "$(dirname "$0")"
[[ -f .env ]] || cp .env.example .env
read -r -p "RDS user: " DB_USER
read -r -s -p "RDS password: " DB_PASS; echo
[[ -n "$DB_USER" && -n "$DB_PASS" ]] || { echo "ERROR: user and password are required"; exit 1; }
TMP=$(mktemp); umask 077
grep -vE '^SQLSERVER_(USER|PASSWORD)=' .env > "$TMP" || true
printf "SQLSERVER_USER=%s\nSQLSERVER_PASSWORD='%s'\n" "$DB_USER" "$DB_PASS" >> "$TMP"
mv "$TMP" .env; chmod 600 .env
echo ".env updated (SQLSERVER_USER and SQLSERVER_PASSWORD)."
