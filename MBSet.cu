/* 
 * File:   MBSet.cu
 * 
 * Created on June 24, 2012, edited 12/07/14 by Tom Wells as part of ECE 4993 project work.
 * 
 * Purpose:  This program displays Mandelbrot set using the GPU via CUDA and
 * OpenGL immediate mode.
 * 
 */

#include <iostream>
#include <stack>
#include <cuda_runtime_api.h>
#include <stdio.h>
#include "Complex.cu"

#include <GL/freeglut.h>
//#include <GL/gl.h>
//#include <GL/glu.h>
//#include <GL/glut.h>
#define WINDOW_DIM            512
#define THREADS		       32
#define BLOCKS		     8192
#define THRESH_SQ		4
#define MAXIT		     2000

__global__ void getColor(int *colorIndex, Complex* min, Complex* max )
{
	int count = 0;
	float dr = (max->r - min->r) / WINDOW_DIM;
	float di = (max->i - min->i) / WINDOW_DIM;
	//mapping
	float real = (blockIdx.x %(WINDOW_DIM / THREADS) + threadIdx.x) * dr;
	float img  = (blockIdx.x / (WINDOW_DIM / THREADS))  *di;
	Complex Z_0(real, img);
	Complex Z_I(Z_0); 
	//itterate Z_n = Z_n-1 ^2 + Z_0
	while(count <=MAXIT && Z_I.magnitude2() <=THRESH_SQ)//magnitude^2 <= 4 iff magnitude <=2
	{
		count++;
		Z_I = (Z_I * Z_I) + Z_0;
	}
	colorIndex[(blockIdx.x * THREADS) + threadIdx.x] = count;
}
using namespace std;

// Initial screen coordinates, both host and device.
// Define the RGB Class
class RGB
{
public:
  RGB()
    : r(0), g(0), b(0) {}
  RGB(double r0, double g0, double b0)
    : r(r0), g(g0), b(b0) {}
public:
  double r;
  double g;
  double b;
};

RGB* colors = 0; // Array of color values
Complex minC(-2.0, -1.2);
Complex maxC(1.0, 1.8);

Complex zoomFactorR(.9,0);
Complex zoomFactorI(0,.9);
int zoomCount = 0;

int *colorIndex;
void InitializeColors()
{
  colors = new RGB[MAXIT + 1];
  for (int i = 0; i < MAXIT; ++i)
    {
      if (i < 5)
        { // Try this.. just white for small it counts
          colors[i] = RGB(1, 1, 1);
        }
      else
        {
          colors[i] = RGB(drand48(), drand48(), drand48());
        }
    }
  colors[MAXIT] = RGB(); // black
}
void keyboard(unsigned char key, int x, int y)
{
	if(key=='q')
	{
		exit(0);
	}
}
void mouse(int button, int state, int x, int y)
{
	//onclick increment zoom count
	//change center point
}
void display(void)
{
//ttrrwsrt
	glClearColor(0.0,0.0,0.0,1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, 1, 1, 0, -1, 1);
	//loop through vertex2d of colors defined in color index
//	for(int i = 0; i<zoomCount; i++)
//	{
//		minC = minC * zoomFactorR;
//		minC = minC * zoomFactorI;

//		maxC = maxC * zoomFactorR;
//		maxC = maxC * zoomFactorI;
//	}
	glBegin(GL_POINTS);
	for(int i = 0; i<WINDOW_DIM; i++)
	{
		for(int j = 0; j<WINDOW_DIM; i++)
		{
			RGB tempC = colors[colorIndex[i*WINDOW_DIM + j]];
			glColor3f(tempC.r, tempC.g, tempC.b);
			glVertex2f((1.0* i)/WINDOW_DIM, (1.0 * j)/WINDOW_DIM);
			
		}
	}
	glEnd();
	glutSwapBuffers();
}
int main(int argc, char** argv)
{
  // Initialize OPENGL here
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_DEPTH | GLUT_DOUBLE | GLUT_RGBA);
	glutInitWindowPosition(100,100);
	glutInitWindowSize(WINDOW_DIM, WINDOW_DIM);
	glViewport(0,0,(GLsizei)WINDOW_DIM, (GLsizei)WINDOW_DIM);
	glEnable(GL_DEPTH_TEST);

	
	glutCreateWindow("Mandelbrot Set");
  // Set up necessary host and device buffers
  // set up the opengl callbacks for display, mouse and keyboard

  // Calculate the interation counts
  // Grad students, pick the colors for the 0 .. 1999 iteration count pixels
	int size = WINDOW_DIM * WINDOW_DIM;//total number of pixels
	InitializeColors();
	//host buffers
	colorIndex = (int*)malloc(size);
	//device buffers
	int *d_colorIndex;
	cudaMalloc((void **)&d_colorIndex, size);
	//window converions bounds

	Complex* d_minC;
	Complex* d_maxC;
	cudaMalloc((void **)&d_minC, sizeof(Complex));
	cudaMalloc((void **)&d_maxC, sizeof(Complex)); 

	glutDisplayFunc(display);
	glutIdleFunc(display);
//	glutKeyboardFunc(keyboard);
//	glutMouseFunc(mouse);

	//move values to cuda
	cudaMemcpy(d_minC, &minC, sizeof(Complex), cudaMemcpyHostToDevice);
	cudaMemcpy(d_maxC, &maxC, sizeof(Complex), cudaMemcpyHostToDevice);

	getColor<<<(WINDOW_DIM*WINDOW_DIM) /THREADS, THREADS>>>(d_colorIndex, d_minC, d_maxC);

	cudaMemcpy(colorIndex, d_colorIndex, size, cudaMemcpyDeviceToHost);
	for(int i = 0; i<512; i++)
	{
		cout<<colorIndex[i]<<"\n";
	} 
//	glutMainLoop(); // THis will callback the display, keyboard and mouse
	free(colorIndex);
	cudaFree(d_colorIndex);
	cudaFree(d_minC);
	cudaFree(d_maxC);
	return 0;
  
}
