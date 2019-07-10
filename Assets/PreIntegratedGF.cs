using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PreIntegratedGF : MonoBehaviour {

const int resolution = 1024;
const int NumSamples = 256;
double saturate(double x)
{
    if (x < 0) x = 0;
    if (x > 1) x = 1;
    return x;
}

int ReverseBits32(int bits)
{
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x00ff00ff) << 8) | ((bits & 0xff00ff00) >> 8);
    bits = ((bits & 0x0f0f0f0f) << 4) | ((bits & 0xf0f0f0f0) >> 4);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xcccccccc) >> 2);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xaaaaaaaa) >> 1);
    return bits;
}

double rand_0_1()
{
    return 1.0 * rand() / RAND_MAX;
}
uint rand_32bit()
{
    uint x = rand() & 0xff;
    x |= (rand() & 0xff) << 8;
    x |= (rand() & 0xff) << 16;
    x |= (rand() & 0xff) << 24;
    return x;
}
// using uniform randomness :(

vec2 Hammersley(int Index, int NumSamples)
{
    double E1 = 1.0 * Index / NumSamples + t1;
    E1 = E1 - Mathf.Floor(E1);
    double E2 = (ReverseBits32(Index) ^ t2) * 2.3283064365386963e-10;
    return vec2(E1, E2);
}

vec3 ImportanceSampleGGX(vec2 E, double Roughness)
{
    double m = Roughness * Roughness;
    double m2 = m * m;

    double Phi = 2 * M_PI * E.x;
    double CosTheta = sqrt((1 - E.y) / (1 + (m2 - 1) * E.y));
    double SinTheta = sqrt(1 - CosTheta * CosTheta);

    vec3 H(SinTheta * cos(Phi), SinTheta * sin(Phi), CosTheta);

    double d = (CosTheta * m2 - CosTheta) * CosTheta + 1;
    double D = m2 / (M_PI*d*d);
    double PDF = D * CosTheta;

    return H;
}

double Vis_SmithJointApprox(double Roughness, double NoV, double NoL)
{
    double a = Roughness * Roughness;
    double Vis_SmithV = NoL * (NoV * (1 - a) + a);
    double Vis_SmithL = NoV * (NoL * (1 - a) + a);
    return 0.5 / (Vis_SmithV + Vis_SmithL);
}

Vector3 IntegrateBRDF(double Roughness, double NoV)
{
    if (Roughness < 0.04) Roughness = 0.04;

    Vector3 V(sqrt(1 - NoV*NoV), 0, NoV);
    double A = 0, B = 0;
    for (int i = 0; i < NumSamples; i++)
    {
        Vector3 E = Hammersley(i, NumSamples);
        Vector3 H = ImportanceSampleGGX(E, Roughness);
        Vector3 L = 2 * V.dot(H) * H - V;

        double NoL = saturate(L.z);
        double NoH = saturate(H.z);
        double VoH = saturate(V.dot(H));

        if (NoL > 0)
        {
            double Vis = Vis_SmithJointApprox(Roughness, NoV, NoL);

            double a = Roughness * Roughness;
            double a2 = a*a;
            double Vis_SmithV = NoL * sqrt(NoV * (NoV - NoV * a2) + a2);
            double Vis_SmithL = NoV * sqrt(NoL * (NoL - NoL * a2) + a2);

            double NoL_Vis_PDF = NoL * Vis * (4 * VoH / NoH);

            double Fc = pow(1 - VoH, 5);
            A += (1 - Fc) * NoL_Vis_PDF;
            B += Fc * NoL_Vis_PDF;
        }
    }
    Vector3 res(A, B);
    res /= NumSamples;
    return res;
}

double t1;
uint t2;
	void CalculateGF()
	{
		 t1 = rand_0_1();
		t2 = rand_32bit();

	    FILE* ppmfile = fopen("PreIntegratedGF.ppm", "wb");
	    fprintf(ppmfile, "P3\n%d %d\n%d\n", resolution, resolution, 255);
	    for (int x = 0; x < resolution; x++)
	    {
	        for (int y = 0; y < resolution; y++)
	        {
	            Vector3 brdf = IntegrateBRDF(1 - 1.0 * x / (resolution - 1), 1.0 * y / (resolution - 1));
	            fprintf(ppmfile, " %03d %03d %03d\n", brdf.x * 255, brdf.y * 255, 0);
	        }
	    }
	    fclose(ppmfile);

	    return 0;
	}
}
