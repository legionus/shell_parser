ESC=$(shell printf "\033")
COLOR_RED=$(ESC)[31m
COLOR_GREEN=$(ESC)[32m
COLOR_RESET=$(ESC)[0m

all:
	perl Build.PL
	./Build

test:
	@! test -e .test.out || { echo 'Please, remove .test.out first' && exit 1; }
	@find t/ -name '*.sh' | sort | while read -r f; \
	do \
		printf "%s" "$$f"; \
		if ./test_parser.pl "$$f" 1>.test.out; then \
			if cmp -s "$${f%.sh}.out" .test.out; then \
				echo ' ok'; \
			else \
				echo ' output changed'; \
				diff -du "$${f%.sh}.out" .test.out | \
					sed -e 's/^+.*/$(COLOR_GREEN)&$(COLOR_RESET)/' \
						-e 's/^-.*/$(COLOR_RED)&$(COLOR_RESET)/' \
					; \
			fi \
		else \
			echo ' failed to parse <----------'; \
		fi; \
		rm .test.out; \
	done

.PHONY: test
