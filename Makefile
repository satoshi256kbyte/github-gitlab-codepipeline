# Main Makefile for CI/CD Pipeline Comparison Project
# This file provides convenient shortcuts to LocalStack operations

.PHONY: help local-test-all local-start local-stop local-clean

# Default target
help:
	@echo "CI/CD Pipeline Comparison Project"
	@echo ""
	@echo "Available commands:"
	@echo "  help           - Show this help message"
	@echo "  local-test-all - Run all CI/CD local tests"
	@echo "  local-start    - Start LocalStack environment"
	@echo "  local-stop     - Stop LocalStack environment"
	@echo "  local-clean    - Clean LocalStack environment"
	@echo ""
	@echo "For more LocalStack commands, use: make -f Makefile.localstack localstack-help"

# Delegate to LocalStack Makefile
local-test-all:
	@make -f Makefile.localstack localstack-test-all

local-start:
	@make -f Makefile.localstack localstack-start

local-stop:
	@make -f Makefile.localstack localstack-stop

local-clean:
	@make -f Makefile.localstack localstack-clean