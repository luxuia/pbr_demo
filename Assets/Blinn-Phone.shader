﻿Shader "DEMO/Blinn-Phone"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_DiffColor("Diff", Color) = (1.0, 0, 0, 1)
		_SpecColor("Spec", Color) = (1, 1, 1, 1)
		_Specular("Specular", range(0, 1)) = 0.1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal:NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
				float3 worldpos : TEXCOORD2;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _DiffColor;
			//float4 _SpecColor;
			float _Specular;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.worldpos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.normal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 normal = normalize(i.normal);
				float3 lightdir = normalize(UnityWorldSpaceLightDir(i.worldpos));
				fixed3 viewdir = normalize(_WorldSpaceCameraPos.xyz - i.worldpos);
				
             //像素颜色采样
                fixed3 texcol = tex2D(_MainTex, i.uv);
                
                //计算环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * texcol;
				//return UNITY_LIGHTMODEL_AMBIENT*2;

				fixed diff = max (0, dot (normal, lightdir));

				fixed3 albedo =  _DiffColor * _LightColor0.rgb*diff;

				fixed3 h = normalize(lightdir + viewdir);
				fixed nh = max(0, dot(normal, h));
				return fixed4(h, 1);

				// *diff 
				fixed3 spec = _SpecColor * pow(nh, _Specular*128) * diff;

				return fixed4( ambient + albedo + spec, 1);
			}
			ENDCG
		}
	}
}
