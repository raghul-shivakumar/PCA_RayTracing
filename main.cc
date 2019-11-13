#include<iostream>
#include "ray.h"

vec3 color(const ray &r)
{
    vec3 unit_direction = unit_vector(r.direction());
    float t = 0.5*(unit_direction.y() + 1.0);
    return (1.0 - t)*vec3(1.0,1.0,1.0) + t*vec3(0.5,0.7,1.0);
}
int main()
{
    int nx=200,ny=100,ir,ig,ib;
    float r,g,b;
    vec3 lower_left_corner(-2.0,-1.0,-1.0);
    vec3 horizontal(4.0,0.0,0.0);
    vec3 vertical(0.0,2.0,0.0);
    vec3 origin(0.0,0.0,0.0);
    std::cout<<"P3\n"<<nx<<" "<<ny<<"\n255\n";
    for(int j = ny-1; j >= 0; j--)
        for(int i =0; i< nx; i++){
            float u = float(i)/float(nx);
            float v = float(j)/float(ny);
            ray r(origin, lower_left_corner + u*horizontal + v*vertical);
            vec3 pixel = color(r);
            ir = int(255.99*pixel[0]);
            ig = int(255.99*pixel[1]);
            ib = int(255.99*pixel[2]);
            std::cout<<ir<<" "<<ig<<" "<<ib<<"\n";
        }
    return 0;
}