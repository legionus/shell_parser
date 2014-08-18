all: ShellParser.pm

ShellParser.pm: ShellParser.yp
	yapp $<

test:
	@find t/ -name '*.sh' | while read -r f; do printf "%s" $$f; ./test_parser.pl $$f >/dev/null 2>&1 && echo ' ok' || echo ' fail <----------'; done

.PHONY: test
