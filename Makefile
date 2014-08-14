all: ShellParser.pm

ShellParser.pm: ShellParser.yp
	yapp $<
