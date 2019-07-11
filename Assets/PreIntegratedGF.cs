using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using UnityEditor;

public class PreIntegratedGF : MonoBehaviour {

const int resolution = 64;
const int NumSamples = 16;
    static float saturate(float x)
{
    if (x < 0) x = 0;
    if (x > 1) x = 1;
    return x;
}

    static ulong ReverseBits32(ulong bits)
{
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x00ff00ff) << 8) | ((bits & 0xff00ff00) >> 8);
    bits = ((bits & 0x0f0f0f0f) << 4) | ((bits & 0xf0f0f0f0) >> 4);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xcccccccc) >> 2);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xaaaaaaaa) >> 1);
    return bits;
}

    static double rand_0_1()
{
        return Random.value;
}
    static uint rand_32bit()
{
        return (uint)Random.Range(0, int.MaxValue);
}
    // using uniform randomness :(

    static Vector2 Hammersley(int Index, int NumSamples)
{
    float E1 = (float)(1.0 * Index / NumSamples + t1);
    E1 = E1 - Mathf.Floor(E1);
    double E2 = (ReverseBits32((ulong)Index) ^ t2) * 2.3283064365386963e-10;
    return new Vector2(E1, (float)E2);
}

    static Vector3 ImportanceSampleGGX(Vector2 E, double Roughness)
{
    double m = Roughness * Roughness;
    double m2 = m * m;

    float Phi = 2 * Mathf.PI * E.x;
        float CosTheta = Mathf.Sqrt(((float)((1 - E.y) / (1 + (m2 - 1) * E.y))));
        float SinTheta = Mathf.Sqrt((float)(1 - CosTheta * CosTheta));

    Vector3 H = new Vector3(SinTheta * Mathf.Cos(Phi), SinTheta * Mathf.Sin(Phi), CosTheta);

    double d = (CosTheta * m2 - CosTheta) * CosTheta + 1;
    double D = m2 / (Mathf.PI*d*d);
    double PDF = D * CosTheta;

    return H;
}

    static double Vis_SmithJointApprox(double Roughness, double NoV, double NoL)
{
    double a = Roughness * Roughness;
    double Vis_SmithV = NoL * (NoV * (1 - a) + a);
    double Vis_SmithL = NoV * (NoL * (1 - a) + a);
    return 0.5 / (Vis_SmithV + Vis_SmithL);
}

    static Vector3 IntegrateBRDF(float Roughness, float NoV)
{
    if (Roughness < 0.04) Roughness = 0.04f;

    Vector3 V = new Vector3(Mathf.Sqrt(1 - NoV*NoV), 0, NoV);
        float A = 0, B = 0;
    for (int i = 0; i < NumSamples; i++)
    {
        Vector3 E = Hammersley(i, NumSamples);
        Vector3 H = ImportanceSampleGGX(E, Roughness);
        Vector3 L = 2 * Vector3.Dot(V,H) * H - V;

        float NoL = saturate(L.z);
            float NoH = saturate(H.z);
            float VoH = saturate(Vector3.Dot( V,H));

        if (NoL > 0)
        {
                float Vis = (float)Vis_SmithJointApprox(Roughness, NoV, NoL);

                float a = Roughness * Roughness;
                float a2 = a*a;
                float Vis_SmithV = NoL * Mathf.Sqrt(NoV * (NoV - NoV * a2) + a2);
                float Vis_SmithL = NoV * Mathf.Sqrt(NoL * (NoL - NoL * a2) + a2);

                float NoL_Vis_PDF = NoL * Vis * (4 * VoH / NoH);

                float Fc = Mathf.Pow(1 - VoH, 5);
            A += (1 - Fc) * NoL_Vis_PDF;
            B += Fc * NoL_Vis_PDF;
        }
    }
    Vector2 res = new Vector2(A, B);
    res /= NumSamples;
    return res;
}

    static double t1;
    static uint t2;
    [MenuItem("Tools/CalculateGF")]
    public static void CalculateGF()
	{
		 t1 = rand_0_1();
		t2 = rand_32bit();

        
        var file = File.OpenWrite("PreIntegratedGF.ppm");

        string content = string.Format("P3\n{0} {1}\n{2}\n", resolution, resolution, 255);

        for (int x = 0; x < resolution; x++)
	    {
	        for (int y = 0; y < resolution; y++)
	        {
	            Vector3 brdf = IntegrateBRDF(1 - 1.0f * x / (resolution - 1), 1.0f * y / (resolution - 1));
                content += string.Format(" {0:D3} {1:D3} {2:D3}\n", Mathf.FloorToInt(brdf.x * 255), Mathf.FloorToInt(brdf.y * 255), 0);
	        }
	    }
        file.Write(System.Text.Encoding.Default.GetBytes(content), 0, content.Length);
        file.Flush();
        file.Close();
        file.Dispose();
	}
}
