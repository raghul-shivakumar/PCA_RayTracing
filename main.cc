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
        if (depth < 50 && rec.mat_ptr->scatter(r, rec, attenuation, scattered))
        {
            return attenuation * color(scattered, world, depth + 1);
        }
        else
        {
            return vec3(0, 0, 0);
        }
        vec3 target = rec.p + rec.normal + random_point_in_unit_sphere();
        return 0.5 * color(ray(rec.p, target - rec.p), world, depth + 1);
    }
    else
    {
        vec3 unit_direction = unit_vector(r.direction());
        float t = 0.5 * (unit_direction.y() + 1.0);
        return (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
    }
}

hittable *random_scene()
{
    int n = 200;
    hittable **list = new hittable *[n + 1];
    list[0] = new sphere(vec3(0, -1000, 0), 1000, new lambertian(vec3(0.5, 0.5, 0.5)));
    int i = 1;
    for (int a = -6; a < 6 ; a++)
    {
        for (int b = -6; b < 6; b++)
        {
            float choose_mat = drand48();
            vec3 center = vec3(a + 0.9 * drand48(), 0.2, b + 0.9 * drand48());
            if ((center - vec3(4, 0.2, 2)).length() > 0.9)
            {
                if (choose_mat < 0.8)
                {
                    list[i++] = new sphere(center, 0.2,
                                           new lambertian(vec3(drand48() * drand48(),
                                                               drand48() * drand48(), drand48() * drand48())));
                }
                else if (choose_mat < 0.95)
                {
                    list[i++] = new sphere(center, 0.2,
                                           new metal(vec3(0.5 * (1 + drand48()),
                                                          0.5 * (1 + drand48()), 0.5 * (1 + drand48())),
                                                     0.5 * drand48()));
                }
                else
                {
                    list[i++] = new sphere(center, 0.2, new dielectric(1.5));
                }
            }
        }
    }
    list[i++] = new sphere(vec3(0,1,0),1.0, new dielectric(1.5));
    list[i++] = new sphere(vec3(-4,1,0),1.0, new lambertian(vec3(0.4,0.2,0.1)));
    list[i++] = new sphere(vec3(4,1,0),1.0, new metal(vec3(0.7,0.6,0.5),0.0));

    return new hittable_list(list,i);
}
int main()
{
    int nx = 400, ny = 200, ns = 100, ir, ig, ib;
    float r, g, b;
    hittable *list[2];
    //list[0] = new sphere(vec3(-R, 0, -1), R, new lambertian(vec3(0, 0, 1)));
    //list[1] = new sphere(vec3(R, 0, -1), R, new lambertian(vec3(1, 0.3, 0)));
    //list[2] = new sphere(vec3(0.5, 0, -1), 0.5, new dielectric(1.5));
    //list[3] = new sphere(vec3(0, -100.5, -1), 100, new lambertian(vec3(0.8,0.8,0.0)));
    hittable *world = random_scene();
    vec3 lookfrom(13, 2, 3);
    vec3 lookat(0, 0, 0);
    float dist_to_focus = 10.0;
    float aperture = 0.1;
    camera cam(lookfrom, lookat, vec3(0, 1, 0), 20, float(nx) / float(ny), aperture, dist_to_focus);
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
            col = vec3(sqrt(col[0]), sqrt(col[1]), sqrt(col[2]));
            ir = int(255.99 * col[0]);
            ig = int(255.99 * col[1]);
            ib = int(255.99 * col[2]);
            std::cout << ir << " " << ig << " " << ib << "\n";
        }
    return 0;
}