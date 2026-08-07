# Development tasks for claudeswitch.
# Requires: bats-core >= 1.4, shellcheck, jq.

.PHONY: test lint check

test:
	bats tests/

lint:
	shellcheck claudeswitch install.sh

check: lint test
