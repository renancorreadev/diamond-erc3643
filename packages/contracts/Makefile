# ─────────────────────────────────────────────────────────────────────────────
# diamond-erc3643 — contracts Makefile
# ─────────────────────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help
.PHONY: help build clean fmt fmt-check lint lint-fix \
        test test-v test-vv test-vvv test-vvvv \
        test-unit test-unit-v test-unit-vv test-unit-vvv \
        test-fuzz test-invariant test-fork \
        test-contract \
        coverage slither \
        deploy-local deploy-dry snapshot

# ─────────────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────────────

RPC_LOCAL   ?= http://localhost:8545
FUZZ_RUNS   ?= 10000
DEPTH       ?= 500
CONTRACT    ?=   # e.g. make test-contract CONTRACT=OwnershipFacet

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  BUILD"
	@echo "    make build          forge build --sizes"
	@echo "    make clean          forge clean"
	@echo "    make snapshot       forge snapshot"
	@echo ""
	@echo "  FORMAT / LINT"
	@echo "    make fmt            forge fmt (write)"
	@echo "    make fmt-check      forge fmt --check"
	@echo "    make lint           solhint src/**/*.sol"
	@echo "    make lint-fix       solhint src/**/*.sol --fix"
	@echo ""
	@echo "  TEST — verbosity"
	@echo "    make test           all tests, -v"
	@echo "    make test-v         all tests, -v"
	@echo "    make test-vv        all tests, -vv"
	@echo "    make test-vvv       all tests, -vvv"
	@echo "    make test-vvvv      all tests, -vvvv"
	@echo ""
	@echo "  TEST — by type"
	@echo "    make test-unit      test/unit/**  -vvv"
	@echo "    make test-unit-v    test/unit/**  -v"
	@echo "    make test-unit-vv   test/unit/**  -vv"
	@echo "    make test-unit-vvv  test/unit/**  -vvv"
	@echo "    make test-fuzz      test/fuzz/**  --fuzz-runs \$$FUZZ_RUNS"
	@echo "    make test-invariant test/invariant/** --fuzz-runs \$$FUZZ_RUNS"
	@echo "    make test-fork      test/fork/**"
	@echo ""
	@echo "  TEST — by contract"
	@echo "    make test-contract CONTRACT=OwnershipFacet"
	@echo "    make test-contract CONTRACT=Diamond"
	@echo ""
	@echo "  COVERAGE / ANALYSIS"
	@echo "    make coverage       forge coverage --report lcov"
	@echo "    make slither        slither . --config-file slither.config.json"
	@echo ""
	@echo "  DEPLOY"
	@echo "    make deploy-local   Deploy.s.sol against local Anvil"
	@echo "    make deploy-dry     Deploy.s.sol simulation (no broadcast)"
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────

build:
	forge build --sizes

clean:
	forge clean

snapshot:
	forge snapshot

# ─────────────────────────────────────────────────────────────────────────────
# Format / Lint
# ─────────────────────────────────────────────────────────────────────────────

fmt:
	forge fmt

fmt-check:
	forge fmt --check

lint:
	npx solhint 'src/**/*.sol'

lint-fix:
	npx solhint 'src/**/*.sol' --fix

# ─────────────────────────────────────────────────────────────────────────────
# Test — all tests, varying verbosity
# ─────────────────────────────────────────────────────────────────────────────

test: test-v

test-v:
	forge test -v

test-vv:
	forge test -vv

test-vvv:
	forge test -vvv

test-vvvv:
	forge test -vvvv

# ─────────────────────────────────────────────────────────────────────────────
# Test — by type
# ─────────────────────────────────────────────────────────────────────────────

test-unit:
	forge test --match-path 'test/unit/**' -vvv

test-unit-v:
	forge test --match-path 'test/unit/**' -v

test-unit-vv:
	forge test --match-path 'test/unit/**' -vv

test-unit-vvv:
	forge test --match-path 'test/unit/**' -vvv

test-fuzz:
	forge test --match-path 'test/fuzz/**' --fuzz-runs $(FUZZ_RUNS) -vvv

test-invariant:
	forge test --match-path 'test/invariant/**' \
		--fuzz-runs $(FUZZ_RUNS) \
		--depth $(DEPTH) \
		-vvv

test-fork:
	forge test --match-path 'test/fork/**' -vvv

# ─────────────────────────────────────────────────────────────────────────────
# Test — by contract name
# usage: make test-contract CONTRACT=OwnershipFacet
# ─────────────────────────────────────────────────────────────────────────────

test-contract:
ifndef CONTRACT
	$(error CONTRACT is required. Usage: make test-contract CONTRACT=OwnershipFacet)
endif
	forge test --match-contract $(CONTRACT) -vvv

# ─────────────────────────────────────────────────────────────────────────────
# Coverage / Analysis
# ─────────────────────────────────────────────────────────────────────────────

coverage:
	forge coverage --report lcov

slither:
	slither . --config-file slither.config.json

# ─────────────────────────────────────────────────────────────────────────────
# Deploy
# ─────────────────────────────────────────────────────────────────────────────

deploy-local:
	ETHERSCAN_API_KEY=dummy \
	forge script script/Deploy.s.sol \
		--rpc-url $(RPC_LOCAL) \
		--broadcast \
		--sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
		--unlocked \
		-vvvv

deploy-dry:
	ETHERSCAN_API_KEY=dummy \
	forge script script/Deploy.s.sol \
		--rpc-url $(RPC_LOCAL) \
		-vvvv
