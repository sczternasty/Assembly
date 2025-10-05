.PHONY: clean

sha1: sha1.s sha1_test64.so
	$(CC) -Wl,-rpath=. -o $@ sha1.s -L. -l:sha1_test64.so

clean:
	rm -f sha1
