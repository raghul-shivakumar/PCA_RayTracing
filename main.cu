#include <iostream>
#include <time.h>
#include <float.h>
#include <curand_kernel.h>
#include "vec3.h"
#include "ray.h"
#include "sphere.h"
#include "hitable_list.h"
#include "camera.h"
#include "material.h"
#include <stdio.h>
#include<cuda_profiler_api.h>

__device__ vec3 color(const ray& r, hitable **world, curandState *local_rand_state) {
    ray cur_ray = r;
    vec3 cur_attenuation = vec3(1.0,1.0,1.0);
    for(int i = 0; i < 50; i++) {
        hit_record rec;
        if ((*world)->hit(cur_ray, 0.001f, FLT_MAX, rec)) {
            ray scattered;
            vec3 attenuation;
            if(rec.mat_ptr->scatter(cur_ray, rec, attenuation, scattered, local_rand_state)) {
                cur_attenuation *= attenuation;
                cur_ray = scattered;
            }
            else {
                return vec3(0.0,0.0,0.0);
            }
        }
        else {
            vec3 unit_direction = unit_vector(cur_ray.direction());
            float t = 0.5f*(unit_direction.y() + 1.0f);
            vec3 c = (1.0f-t)*vec3(1.0, 1.0, 1.0) + t*vec3(0.5, 0.7, 1.0);
            return cur_attenuation * c;
        }
    }
    return vec3(0.0,0.0,0.0);
}

__global__ void rand_init(curandState *rand_state) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        curand_init(1984, 0, 0, rand_state);
    }
}

__global__ void render_init(int max_x, int max_y, curandState *rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if((i >= max_x) || (j >= max_y)) return;
    int pixel_index = j*max_x + i;
    curand_init(1984, pixel_index, 0, &rand_state[pixel_index]);
}

__global__ void render(vec3 *fb, int max_x, int max_y, int ns, camera **cam, hitable **world, curandState *rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if((i >= max_x) || (j >= max_y)) return;
    int pixel_index = j*max_x + i;
    curandState local_rand_state = rand_state[pixel_index];
    vec3 col(0,0,0);
    for(int s=0; s < ns; s++) {
        float u = float(i + curand_uniform(&local_rand_state)) / float(max_x);
        float v = float(j + curand_uniform(&local_rand_state)) / float(max_y);
        ray r = (*cam)->get_ray(u, v, &local_rand_state);
        col += color(r, world, &local_rand_state);
    }
    rand_state[pixel_index] = local_rand_state;
    col /= float(ns);
    col[0] = sqrt(col[0]);
    col[1] = sqrt(col[1]);
    col[2] = sqrt(col[2]);
    fb[pixel_index] = col;
}

#define RND (curand_uniform(&local_rand_state))

__global__ void create_world(hitable **d_list, hitable **d_world, camera **d_camera, int nx, int ny, curandState *rand_state) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        curandState local_rand_state = *rand_state;
        d_list[0] = new sphere(vec3(0,-1000.0,-1), 1000,
                               new lambertian(vec3(0.5, 0.5, 0.5)));
        int i = 1;
        for(int a = -11; a < 11; a++) {
            for(int b = -11; b < 11; b++) {
                float choose_mat = RND;
                vec3 center(a+RND,0.2,b+RND);
                if(choose_mat < 0.8f) {
                    d_list[i++] = new sphere(center, 0.2,
                                             new lambertian(vec3(RND*RND, RND*RND, RND*RND)));
                }
                else if(choose_mat < 0.95f) {
                    d_list[i++] = new sphere(center, 0.2,
                                             new metal(vec3(0.5f*(1.0f+RND), 0.5f*(1.0f+RND), 0.5f*(1.0f+RND)), 0.5f*RND));
                }
                else {
                    d_list[i++] = new sphere(center, 0.2, new dielectric(1.5));
                }
            }
        }
        d_list[i++] = new sphere(vec3(0, 1,0),  1.0, new dielectric(1.5));
        d_list[i++] = new sphere(vec3(-4, 1, 0), 1.0, new lambertian(vec3(0.4, 0.2, 0.1)));
        d_list[i++] = new sphere(vec3(4, 1, 0),  1.0, new metal(vec3(0.7, 0.6, 0.5), 0.0));
        *rand_state = local_rand_state;
        *d_world  = new hitable_list(d_list, 22*22+1+3);

        vec3 lookfrom(13,2,3);
        vec3 lookat(0,0,0);
        float dist_to_focus = 10.0; (lookfrom-lookat).length();
        float aperture = 0.1;
        *d_camera   = new camera(lookfrom,
                                 lookat,
                                 vec3(0,1,0),
                                 30.0,
                                 float(nx)/float(ny),
                                 aperture,
                                 dist_to_focus);
    }
}

__global__ void free_world(hitable **d_list, hitable **d_world, camera **d_camera) {
    for(int i=0; i < 22*22+1+3; i++) {
        delete ((sphere *)d_list[i])->mat_ptr;
        delete d_list[i];
    }
    delete *d_world;
    delete *d_camera;
}

int main(int argc, char* argv[]) {

    if(argc < 2){
        printf("Please enter the values of nx, ny, ns, tx and ty\n");
        return 0;
    }
    int nx = atoi(argv[1]);
    int ny = atoi(argv[2]);
    int ns = atoi(argv[3]);
    int tx = atoi(argv[4]);
    int ty = atoi(argv[5]);

    float ms = 0;
    std::cerr << "Rendering a " << nx << "x" << ny << " image with " << ns << " samples per pixel ";
    std::cerr << "in " << tx << "x" << ty << " blocks.\n";
    FILE* fp;
    int num_pixels = nx*ny;
    size_t fb_size = num_pixels*sizeof(vec3);
    cudaEvent_t start_create_world,stop_create_world,start_render_init,stop_render_init,
                    start_render,stop_render;
    // allocate FB
    vec3 *fb;
    cudaError_t err;
    err = cudaMallocManaged((void **)&fb, fb_size);
    printf("CUDA malloc managed of Frame Buffers: %s\n",cudaGetErrorString(err));

    // allocate random state
    curandState *d_rand_state;
    err = cudaMalloc((void **)&d_rand_state, num_pixels*sizeof(curandState));
    printf("CUDA malloc d_rand_state: %s\n",cudaGetErrorString(err));
    curandState *d_rand_state2;
    err = cudaMalloc((void **)&d_rand_state2, 1*sizeof(curandState));
    printf("CUDA malloc d_rand_state2: %s\n",cudaGetErrorString(err));

    // we need that 2nd random state to be initialized for the world creation
    rand_init<<<1,1>>>(d_rand_state2);
    
    err = cudaDeviceSynchronize();
    printf("CUDA device synchronize%s\n",cudaGetErrorString(err));

    // make our world of hitables & the camera
    hitable **d_list;
    int num_hitables = 22*22+1+3;
    err = cudaMalloc((void **)&d_list, num_hitables*sizeof(hitable *));
    printf("CUDA d_list: %s\n",cudaGetErrorString(err));
    hitable **d_world;
    err = cudaMalloc((void **)&d_world, sizeof(hitable *));
    printf("CUDA malloc d_world: %s\n",cudaGetErrorString(err));
    camera **d_camera;
    err = cudaMalloc((void **)&d_camera, sizeof(camera *));
    printf("CUDA malloc d_camera: %s\n",cudaGetErrorString(err));
    cudaEventCreate(&start_create_world);
    cudaEventCreate(&stop_create_world);
    cudaEventRecord(start_create_world);
    create_world<<<1,1>>>(d_list, d_world, d_camera, nx, ny, d_rand_state2);
    err = cudaGetLastError();
    printf("CUDA kernel create_world: %s\n",cudaGetErrorString(err));
    err = cudaDeviceSynchronize();
    printf("CUDA device synchronize: %s\n",cudaGetErrorString(err));
    cudaEventRecord(stop_create_world);
    ms = 0;
    cudaEventElapsedTime(&ms,start_create_world,stop_create_world);
    printf("The time taken by the function create_world() is: %2.3f ms\n",ms);

    clock_t start, stop;
    start = clock();
    // Render our buffer
    dim3 blocks(nx/tx+1,ny/ty+1);
    dim3 threads(tx,ty);
    cudaEventCreate(&start_render_init);
    cudaEventCreate(&stop_render_init);
    cudaEventRecord(start_render_init);   
    render_init<<<blocks, threads>>>(nx, ny, d_rand_state);
    err = cudaDeviceSynchronize();
    cudaEventRecord(stop_render_init);
    printf("CUDA device synchronize: %s\n",cudaGetErrorString(err));
    float ms2 = 0;
    cudaEventElapsedTime(&ms2,start_render_init,stop_render_init);
    printf("The time taken by the function render_init() is: %2.3f ms\n",ms2);

    cudaEventCreate(&start_render);
    cudaEventCreate(&stop_render);
    cudaEventRecord(start_render); 
    render<<<blocks, threads>>>(fb, nx, ny,  ns, d_camera, d_world, d_rand_state);
    err = cudaDeviceSynchronize();
    printf("CUDA device synchronize: %s\n",cudaGetErrorString(err));
    cudaEventRecord(stop_render);
    float ms3 = 0;
    cudaEventElapsedTime(&ms3,start_render,stop_render);
    err = cudaGetLastError();
    printf("CUDA kernel render: %s\n",cudaGetErrorString(err));
    cudaEventElapsedTime(&ms3,start_render,stop_render);
    printf("The time taken by the function render() is: %2.3f ms\n",ms3); 
    stop = clock();
    double timer_seconds = ((double)(stop - start)) / CLOCKS_PER_SEC;
    //std::cerr << "took " << timer_seconds << " seconds for the render function.\n";

    // Output FB as Image
    fp = fopen("output.ppm","wb");
    fprintf(fp,"P3\n");
    fprintf(fp,"%d %d\n",nx,ny);
    fprintf(fp,"255\n");
    
    for (int j = ny-1; j >= 0; j--) {
        for (int i = 0; i < nx; i++) {
            size_t pixel_index = j*nx + i;
            int ir = int(255.99*fb[pixel_index].r());
            int ig = int(255.99*fb[pixel_index].g());
            int ib = int(255.99*fb[pixel_index].b());
            fprintf(fp,"%d %d %d\n",ir,ig,ib);
        }
    }
    fclose(fp);

    // clean up
    err = cudaDeviceSynchronize();
    printf("CUDA device synchroize: %s\n",cudaGetErrorString(err));
    free_world<<<1,1>>>(d_list,d_world,d_camera);
    err = cudaGetLastError();
    printf("CUDA kernel free_world: %s\n",cudaGetErrorString(err));
    err = cudaFree(d_camera);
    printf("CUDA free d_camera: %s\n",cudaGetErrorString(err));
    err = cudaFree(d_world);
    printf("CUDA free d_world: %s\n",cudaGetErrorString(err));
    err = cudaFree(d_list);
    printf("CUDA free d_list: %s\n",cudaGetErrorString(err));
    err = cudaFree(d_rand_state);
    printf("CUDA free d_rand_state: %s\n",cudaGetErrorString(err));
    err = cudaFree(fb);
    printf("CUDA free fb: %s\n",cudaGetErrorString(err));
}
