Shader "Arc/ArcHandWritePbr"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Tint("Tint", Color) = (1 ,1 ,1 ,1)
		[Gamma] _Metallic("Metallic", Range(0, 1)) = 0 //金属度要经过伽马校正
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		_LUT("LUT", 2D) = "white" {}

		[Toggle]_FACTOR_D("D", Int) = 0
		[Toggle]_FACTOR_V("V", Int) = 0
		[Toggle]_FACTOR_G("G", Int) = 0
		[Toggle]_FACTOR_F("F", Int) = 0

		[Toggle]_DIR_SPECULAR("直接光_镜面反射", Int) = 0
		[Toggle]_DIR_DIFFUSE("直接光_漫反射", Int) = 0
		[Toggle]_DIR_SUM("直接光_总", Int) = 0

		[Toggle]_INDIR_SPECULAR("间接光_镜面反射", Int) = 0
		[Toggle]_INDIR_DIFFUSE("间接光_漫反射", Int) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
			Tags {
				"LightMode" = "ForwardBase"
			}
            CGPROGRAM
			

			#pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

			#include "UnityStandardBRDF.cginc" 

            struct appdata
            {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
			};

			float4 _Tint;
			float _Metallic;
			float _Smoothness;
            sampler2D _MainTex;
            float4 _MainTex_ST;
			sampler2D _LUT;

			#pragma shader_feature _FACTOR_D_ON _FACTOR_G_ON _FACTOR_V_ON _FACTOR_F_ON
			#pragma shader_feature _DIR_SPECULAR_ON _DIR_DIFFUSE_ON

			#pragma shader_feature _INDIR_SPECULAR_ON _INDIR_DIFFUSE_ON _INDIR_SPECULAR_ON _INDIR_DIFFUSE_ON

            v2f vert (appdata v)
            {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.normal = normalize(o.normal);
				return o;
            }

			float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			{
				return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}

            fixed4 frag (v2f i) : SV_Target
            {
				i.normal = normalize(i.normal);
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				float3 lightColor = _LightColor0.rgb;
				float3 halfVector = normalize(lightDir + viewDir);  //半角向量

				float perceptualRoughness = 1 - _Smoothness;

				float roughness = perceptualRoughness * perceptualRoughness;
				float squareRoughness = roughness * roughness;

				float nl = max(saturate(dot(i.normal, lightDir)), 0.000001);//防止除0
				float nv = max(saturate(dot(i.normal, viewDir)), 0.000001);
				float vh = max(saturate(dot(viewDir, halfVector)), 0.000001);
				float lh = max(saturate(dot(lightDir, halfVector)), 0.000001);
				float nh = max(saturate(dot(i.normal, halfVector)), 0.000001);			

				//漫反射部分
                float3 Albedo = _Tint * tex2D(_MainTex, i.uv);
				//float4 diffuseResult = float4(Albedo.rgb, 1);//理论上要除pi 但是unity为了保证效果和legacy效果差不多所以主光源没有除
				//UnitystandardBRDF.cginc 271行
				//环境光
				float3 ambient = 0.03 * Albedo;

				//镜面反射部分
				//D是镜面分布函数，从统计学上估算微平面的取向
				float lerpSquareRoughness = pow(lerp(0.002, 1, roughness), 2);//Unity把roughness lerp到了0.002
				float D = lerpSquareRoughness / (pow((pow(nh, 2) * (lerpSquareRoughness - 1) + 1), 2) * UNITY_PI);

				#ifdef _FACTOR_D_ON
					return fixed4(D, D, D, 1);
				#endif
				
				//几何遮蔽G 说白了就是高光
				float kInDirectLight = pow(squareRoughness + 1, 2) / 8;
				float kInIBL = pow(squareRoughness, 2) / 8;
				float GLeft = nl / lerp(nl, 1, kInDirectLight);
				float GRight = nv / lerp(nv, 1, kInDirectLight);
				float G = GLeft * GRight;

				#ifdef _FACTOR_G_ON
					return fixed4(G, G, G, 1);
				#endif

				//菲涅尔F
				
				//unity_ColorSpaceDielectricSpec.rgb这玩意大概是float3(0.04, 0.04, 0.04)，就是个经验值
				float3 F0 = lerp(unity_ColorSpaceDielectricSpec.rgb, Albedo, _Metallic);
				//float3 F = lerp(pow((1 - max(vh, 0)),5), 1, F0);//是hv不是nv
				float3 F = F0 + (1 - F0) * exp2((-5.55473 * vh - 6.98316) * vh);
				#ifdef _FACTOR_F_ON
					return fixed4(F, 1);
				#endif
				//镜面反射结果
				float3 SpecularResult = (D * G * F * 0.25)/(nv * nl);
				
				//漫反射系数
				float3 kd = (1 - F)*(1 - _Metallic);
				
				//直接光照部分结果
				float3 specColor = SpecularResult * lightColor * nl * FresnelTerm(1, lh) * UNITY_PI;
				#ifdef _DIR_SPECULAR_ON
					return fixed4(specColor, 1);
				#endif
				float3 diffColor = kd * Albedo * lightColor * nl;
				#ifdef _DIR_DIFFUSE_ON
					return fixed4(diffColor, 1);
				#endif
				float3 DirectLightResult = diffColor + specColor;
				#ifdef _DIR_SUM
					return fixed4(DirectLightResult, 1);
				#endif

				
				//ibl部分
				half3 ambient_contrib = ShadeSH9(float4(i.normal, 1));
				/*
				half3 ambient_contrib = 0.0;
				ambient_contrib.r = dot(unity_SHAr, half4(i.normal, 1.0));
				ambient_contrib.g = dot(unity_SHAg, half4(i.normal, 1.0));
				ambient_contrib.b = dot(unity_SHAb, half4(i.normal, 1.0));
				*/

				float3 iblDiffuse = max(half3(0, 0, 0), ambient + ambient_contrib);

				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				float3 reflectVec = reflect(-viewDir, i.normal);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectVec, mip); //根据粗糙度生成lod级别对贴图进行三线性采样

				float3 iblSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);

				float2 envBDRF = tex2D(_LUT, float2(lerp(0, 0.99 ,nv), lerp(0, 0.99, roughness))).rg; // LUT采样
				
				float3 Flast = fresnelSchlickRoughness(max(nv, 0.0), F0, roughness);
				float kdLast = (1 - Flast) * (1 - _Metallic);
				
				float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;
				float3 iblSpecularResult = iblSpecular * (Flast * envBDRF.r + envBDRF.g);
				float3 IndirectResult = iblDiffuseResult + iblSpecularResult;
				
				/*
				float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
				//float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;  //Gamma空间
				float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
				float grazingTerm = saturate(_Smoothness + (1 - oneMinusReflectivity));
				float4 IndirectResult = float4(iblDiffuse * kdLast * Albedo + iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nv), 1);		
				*/
				#ifdef _INDIR_DIFFUSE_ON
				return fixed4(iblDiffuseResult, 1);
				#endif
				#ifdef _INDIR_SPECULAR_ON
				return fixed4(iblSpecularResult, 1);
				#endif

				float4 result = float4(DirectLightResult+IndirectResult, 1);
				
				return result;
            }

            ENDCG
        }
    }
}
