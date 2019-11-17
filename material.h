#ifndef MATERIALH
#define MATERIALH

#include "ray.h"
#include "hittable.h"

vec3 random_point_in_unit_sphere(){
    vec3 p;
    do{
        p = 2.0*vec3(drand48(),drand48(),drand48()) - vec3(1,1,1);
    }while(p.squared_length() >= 1.0);
    return p;
}

vec3 reflect(const vec3 v, const vec3 n){
    return v - 2*dot(v,n)*n;
}
float p = 1.00;
class material{
    public:
        virtual bool scatter(const ray& r_in, const hit_record& rec, vec3& attenution, ray& scattered) const = 0;
};

class lambertian : public material{
    public:
        lambertian(const vec3& a) : albedo(a) {}
        virtual bool scatter(const ray& r_in, const hit_record& rec, vec3& attenuation, ray& scattered) const {
            vec3 target = rec.p + rec.normal + random_point_in_unit_sphere();
            scattered = ray(rec.p,target-rec.p);
            attenuation = albedo/p;
            return true;
        }

        vec3 albedo;  
};

class metal : public material{
    public:
        metal(const vec3& a) : albedo(a) {}
        virtual bool scatter(const ray& r_in, const hit_record& rec, vec3& attenuation, ray& scattered) const {
            vec3 reflected = reflect(unit_vector(r_in.direction()),rec.normal);
            scattered = ray(rec.p,reflected);
            attenuation = albedo/p;
            return (dot(scattered.direction(),rec.normal)>0);
        }

        vec3 albedo;  
};
#endif