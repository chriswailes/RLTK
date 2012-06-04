CC		= gcc
LFLAGS	= -fPIC

all: libkazoo.so

libkazoo.so: kazoo.c
	$(CC) $(LFLAGS) -c -o kazoo.o $<
	$(CC) -shared -Wl,-soname,libkazoo.so -o libkazoo.so kazoo.o

.PHONY: clean
clean:
	rm -f kazoo.o libkazoo.so
