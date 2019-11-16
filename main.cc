#include <iostream>
#include <stdlib.h>
#include "sphere.h"
#include "hittable_list.h"
#include "camera.h"
#include <float.h>

vec3 random_point_in_unit_sphere(){
    vec3 p;
    do{
        p = 2.0*vec3(drand48(),drand48(),drand48()) - vec3(1,1,1);
    }while(p.squared_length() >= 1.0);
    return p;
}
vec3 color(const ray &r, hittable *world)
{
    hit_record rec;
    if (world->hit(r, 0.001, FLT_MAX, rec))
    {
        vec3 target = rec.p + rec.normal + random_point_in_unit_sphere();
        return 0.5*color(ray(rec.p,target - rec.p),world);
    }
    else
    {
        vec3 unit_direction = unit_vector(r.direction());
        float t = 0.5 * (unit_direction.y() + 1.0);
        return (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
    }
}
int main()
{
    int nx = 2000, ny = 1000, ns = 100, ir, ig, ib;
    float r, g, b;
    camera cam;
    hittable *list[2];
    list[0] = new sphere(vec3(0, 0, -1), 0.5);
    list[1] = new sphere(vec3(0, -100.5, -1), 100);
    hittable *world = new hittable_list(list, 2);
    std::cout << "P3\n"
              << nx << " " << ny << "\n255\n";
    for (int j = ny - 1; j >= 0; j--)
        for (int i = 0; i < nx; i++)
        {
            vec3 col(0, 0, 0);
            for (int s = 0; s < ns; s++)
            {
                float u = float(i + drand48()) / float(nx);
                float v = float(j + drand48()) / float(ny);
                ray r = cam.get_ray(u, v);
                vec3 p = r.point_at_parameter(2.0);
                col += color(r, world);
            }
            col /= float(ns);
            col = vec3(sqrt(col[0]),sqrt(col[1]),sqrt(col[2]));
            ir = int(255.99 * col[0]);
            ig = int(255.99 * col[1]);
            ib = int(255.99 * col[2]);
            std::cout << ir << " " << ig << " " << ib << "\n";
        }
    return 0;
}