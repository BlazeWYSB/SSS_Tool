Shader "Custom/SSS_CurvrMap"{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_CurveTex ("CurveMap", 2D) = "white" {}
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SSSLUT ("SSSLUT", 2D) = "white" {}
		_Gloss ("Gloss", Range(8.0, 256)) = 20
		_CurveFactor("CurveRate",Range(1,4))=1
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		Pass
		{
			Tags  {"LightMode" = "ForwardBase"}
 
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase
			//#include "Lighting.cginc"
 
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			sampler2D _MainTex;
			sampler2D _CurveTex;
			float4 _MainTex_ST;
			sampler2D _SSSLUT;
			fixed4 _Color;
			fixed4 _Specular;
			float _Gloss;
			float _CurveFactor;
			struct appdata
			{
				float4 vertex : POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
 
			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD1;
				float3 normal : TEXCOORD2;
				SHADOW_COORDS(4)
			};
 
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
 
				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
 
				o.worldPos = worldPos;
				o.normal = v.normal;
				TRANSFER_SHADOW(o);
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				fixed shadow = SHADOW_ATTENUATION(i);
 
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
 
				fixed3 tangentNormal=normalize(i.normal);
 
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
				fixed curve=tex2D(_CurveTex, i.uv.xy).r;
				fixed3 ambient = clamp(UNITY_LIGHTMODEL_AMBIENT.xyz,0,0.2) * albedo;
 
				fixed3 halfDir = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
				
				float NoL=dot(tangentNormal,lightDir);
				fixed3 diffuse = _LightColor0.rgb * albedo *tex2D(_SSSLUT,float2(NoL*0.5+0.5,curve* _CurveFactor)) * shadow;
				return fixed4(diffuse+ambient+specular, 1.0);
			}
			ENDCG
		}
		Pass
		{
			Tags  {"LightMode" = "ForwardAdd"}
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			sampler2D _MainTex;
			sampler2D _CurveTex;
			float4 _MainTex_ST;
			sampler2D _SSSLUT;
			fixed4 _Color;
			fixed4 _Specular;
			float _Gloss;
			float _CurveFactor;
			struct appdata
			{
				float4 vertex : POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
 
			struct v2f
			{
				float4 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD1;
				float3 normal : TEXCOORD2;
			};
 
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
 
				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
 
				o.worldPos = worldPos;
				o.normal = v.normal;
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下可以直接获取世界空间下的光照方向
					fixed3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				#else  //其他光源下_WorldSpaceLightPos0代表光源的世界坐标，与顶点的世界坐标的向量相减可得到世界空间下的光照方向
					fixed3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
 
				
 
				fixed3 tangentNormal=normalize(i.normal);
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
				fixed curve=tex2D(_CurveTex, i.uv.xy).r;
 
				fixed3 halfDir = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
				
				float NoL=dot(tangentNormal,lightDir);
				fixed3 diffuse = _LightColor0.rgb * albedo *tex2D(_SSSLUT,float2(NoL*0.5+0.5,curve* _CurveFactor));



				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下不存在光照衰减，恒值为1
					fixed atten = 1.0;
				#else
					#if defined (POINT)    //点光源的光照衰减计算
						//unity_WorldToLight内置矩阵，世界空间到光源空间变换矩阵。与顶点的世界坐标相乘可得到光源空间下的顶点坐标
						float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
						//利用Unity内置函数tex2D对Unity内置纹理_LightTexture0进行纹理采样计算光源衰减，获取其衰减纹理，
						//再通过UNITY_ATTEN_CHANNEL得到衰减纹理中衰减值所在的分量，以得到最终的衰减值
						fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#elif defined (SPOT)   //聚光灯的光照衰减计算
						float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
						//(lightCoord.z > 0)：聚光灯的深度值小于等于0时，则光照衰减为0
						//_LightTextureB0：如果该光源使用了cookie，则衰减查找纹理则为_LightTextureB0
						fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					
					#else
						fixed atten = 1.0;
					#endif
				#endif

				return fixed4((diffuse+specular)*atten, 1.0);
			}
			ENDCG
		}
	}
 
	FallBack "Specular"
}

