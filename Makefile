CC = g++
CFLAGS = -I.

DEPS = ray.h,vec3.h,hittable.h,sphere.h,camera.h

%.o: %.c $(DEPS)
		$(CC) -c -o $@ $< $(CFLAGS)

main: main.o
	$(CC) -o main main.o

clean: 
	rm main main.o