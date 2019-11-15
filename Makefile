CC = g++
CFLAGS = -I.

DEPS = ray.h,vec3.h,hittable.h,sphere.h

%.o: %.c $(DEPS)
		$(CC) -c -o $@ $< $(CFLAGS)

main: main.o
	$(CC) -o main main.o