CC = g++
CFLAGS = -g,-pg,-I.

DEPS = ray.h,vec3.h,hittable.h,sphere.h,camera.h,material.h

%.o: %.c $(DEPS)
		$(CC) -c -o $@ $< $(CFLAGS)

main: main.o
	$(CC) -o main main.o -pg

clean: 
	rm main main.o