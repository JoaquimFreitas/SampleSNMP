CC=gcc
CFLAGS+=-Wall -g

.PHONY: all clean

all: smallsnmp

smallsnmp: main.c snmp.o snmp.h db.o db.h
	$(CC) $(CFLAGS) main.c snmp.o db.o -o smallsnmp

clean:
	@rm -f *.o
	@rm -f smallsnmp

