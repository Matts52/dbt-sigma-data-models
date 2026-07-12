#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INT_TESTS_DIR="$REPO_ROOT/integration_tests"

echo "=== dbt-sigma-data-models Integration Tests (DuckDB) ==="
echo ""

mkdir -p "$REPO_ROOT/duckdb"

cd "$INT_TESTS_DIR"

echo "1. Installing dependencies..."
dbt deps --profile sigma_integration_tests_duckdb

echo ""
echo "2. Loading seed data..."
dbt seed --profile sigma_integration_tests_duckdb

echo ""
echo "3. Running dbt models..."
dbt run --profile sigma_integration_tests_duckdb

echo ""
echo "4. Parsing to verify the compiled Sigma spec (no partial parse)..."
dbt parse --profile sigma_integration_tests_duckdb --no-partial-parse

echo ""
echo "=== All tests passed! ==="
