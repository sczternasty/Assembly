debug:
	gcc test.o solution.s -g -no-pie -o out

test:
	gcc test.o solution.s -g -no-pie -o out
