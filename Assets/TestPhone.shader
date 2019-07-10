Shader "Unlit/PhongLightModel"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}//主贴图
        _MainColor ("Main Color", Color) = (1.0, 1.0, 1.0, 1.0)//主颜色，默认白色
        _SpecularColor ("Specular Color", Color) = (0, 0, 0, 1.0)//高光颜色，默认黑色
        _Shininess ("Gloss", Range(0.0, 10)) = 0.5//反光度
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc" 

            struct a2v
            {
                float4 vertex : POSITION;//顶点
                float2 uv : TEXCOORD0;//uv
                float3 normal : NORMAL;//法线
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;//顶点
                float3 worldLightDir:TEXCOORD1;//世界坐标系下的指向光源的矢量
                float3 worldNormal:TEXCOORD2;//世界坐标系下法线
                float3 worldViewDir :TEXCOORD3; //世界坐标系下的指向观察者的矢量
                float4 pos : SV_POSITION;//裁剪坐标下的顶点
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _SpecularColor;
            fixed4 _MainColor;
            float _Shininess;
            
            v2f vert (a2v v)
            {
                v2f o;

                //使用UNITY_MATRIX_MVP矩阵做仿射变换，把模型空间下的顶点转到裁剪坐标下
                o.pos = mul(UNITY_MATRIX_MVP,v.vertex);
                
                //取得世界坐标系下的法线,UnityObjectToWorldNormal()在UnityCG.cginc被定义
                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                //取得世界坐标系下的指向光源的矢量，WorldSpaceLightDir()在UnityCG.cginc被定义
                o.worldLightDir = WorldSpaceLightDir(v.vertex);

                //取得世界坐标系下的指向观察者的矢量，WorldSpaceLightDir()在UnityCG.cginc被定义
                o.worldViewDir = WorldSpaceViewDir(v.vertex);

                //uv采样
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                //归一化
                fixed3 normalizedLightDir  = normalize(i.worldLightDir);
                fixed3 normalizedNormal = normalize(i.worldNormal);
                fixed3 normalizedViewDir = normalize(i.worldViewDir);

                //像素颜色采样
                fixed3 albedo = tex2D(_MainTex, i.uv);
                
                //计算环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                //计算漫反射
                fixed3 diffuse = (_LightColor0.rgb * albedo) * saturate(dot(normalizedNormal,normalizedLightDir));

                //计算高光
                fixed3 halfDir = normalize(normalizedViewDir + normalizedLightDir);
                fixed3 specular = (_SpecularColor.rgb * _LightColor0.rgb) * pow(saturate(dot(halfDir,normalizedNormal )),_Shininess);

                return fixed4((ambient+diffuse+specular),1);
            }
            ENDCG
        }
    }
    FallBack  "Specular"
}