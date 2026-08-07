# Development tasks for claudeswitch.
# Requires: bats-core >= 1.4, shellcheck, jq.

.PHONY: test lint check

test:
	bats tests/

lint:
	shellcheck claudeswitch install.sh
	@if grep -n '\[\[' tests/*.bats; then \
	  echo 'error: bare [[ ]] in tests - bash 3.2 errexit ignores its failures; use the assert_* helpers' >&2; \
	  exit 1; \
	fi

check: lint test
