#include <iostream>
#include <stdlib.h>
#include "sphere.h"
#include "hittable_list.h"
#include "camera.h"
#include "material.h"
#include <float.h>


vec3 color(const ray &r, hittable *world, int depth)
{
    hit_record rec;
    if (world->hit(r, 0.001, FLT_MAX, rec))
    {
        ray scattered;
        vec3 attenuation;
        if(depth < 50 && rec.mat_ptr->scatter(r,rec,attenuation,scattered)){
            return attenuation*color(scattered,world,depth+1);
        }
        else{
            return vec3(0,0,0);
        }
        vec3 target = rec.p + rec.normal + random_point_in_unit_sphere();
        return 0.5*color(ray(rec.p,target - rec.p),world,depth+1);
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
    int nx = 400, ny = 200, ns = 100, ir, ig, ib;
    float r, g, b;
    camera cam;
    hittable *list[4];
    list[0] = new sphere(vec3(-0.5, 0, -1), 0.5, new metal(vec3(1.0,0.3,0.3)));
    list[1] = new sphere(vec3(0, -100.5, -1), 100, new lambertian(vec3(0.8,0.8,0.0)));
    list[2] = new sphere(vec3(0.5, 0, -1), 0.5, new metal(vec3(0.2,0.8,0.3)));
    //list[3] = new sphere(vec3(0, -100.5, -1), 100, new lambertian(vec3(0.8,0.8,0.0)));
    hittable *world = new hittable_list(list, 3);
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
                col += color(r, world, 0);
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