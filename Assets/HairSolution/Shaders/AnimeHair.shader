Shader "Custom/AnimeHair"{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_AnisotropicPowerValue ("AnisotropicValue", Range(20,400)) = 1.0
		_AnisotropicPowerScale ("AnisotropicScale", Float) = 1.0
		[HDR]_RimColor("Rim Color", Color) = (1, 1, 1, 1)
		_RimSmooth("RimSmooth", Float) = 1.0
		_RimMin("RimMin", Float) = 1.0
		_RimMax("RimMax", Float) = 1.0
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
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile_fog
 
 
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed4 _RimColor;
			float _AnisotropicPowerValue;
			float _AnisotropicPowerScale;
			float _RimMin;
			float _RimMax;
			float _RimSmooth;

		
			struct appdata
			{
				float4 vertex : POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
 
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float3 tangent : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				float3 bi : TEXCOORD4;
				float4 pos : CLIP_POS;
				SHADOW_COORDS(5)
                UNITY_FOG_COORDS(6)
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex= UnityObjectToClipPos(v.vertex);
				o.pos = UnityObjectToClipPos(v.vertex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent);
				o.bi = cross(worldNormal, worldTangent) * v.tangent.w; 

				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				
				
 
				o.normal = worldNormal;
				o.tangent = worldTangent;
				o.worldPos = worldPos;
				TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}
			

 
			fixed4 frag (v2f i) : SV_Target
			{
				//Basis
				fixed shadow = SHADOW_ATTENUATION(i);
				float3 worldPos = normalize(i.worldPos);
				float3 N_low = normalize(i.normal);
				float3 tang = normalize(i.tangent.xyz);
				fixed3 binormal = cross(N_low, tang) ; 
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

				//rim
				half f =  1.0 - saturate(dot(viewDir, N_low));
				half rim = smoothstep(_RimMin, _RimMax, f);
				rim = smoothstep(0, _RimSmooth, rim);
				half3 rimColor = rim * _RimColor.rgb *  _RimColor.a;
		
				//Ambient
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
				fixed3 ambient = albedo*0.2;
 
				//SPECULAR
				fixed3 H = normalize(viewDir + lightDir);
				//因为 sin^2+cos^2 =1 所以 sin = sqrt(1-cos^2)
				float dotTH = dot(binormal,H);
				float sinTH = sqrt(1- dotTH*dotTH);

				float dirAtten = smoothstep(-1,0,dotTH);
				float Specular= dirAtten * pow(sinTH,_AnisotropicPowerValue)*_AnisotropicPowerScale;
				//Specular  =  pow(dot(binormal,H),_AnisotropicPowerValue);
			
				float3 diffuse=saturate(dot(lightDir, N_low))* albedo;
				//fixed3 diffuse=_LightColor0.rgb * albedo  * shadow;
				//diffuse = tex2D(_SSSLUT,float2(NoL*0.5+0.5,cuv));
				//diffuse = fixed4(curve* _CurveFactor,curve* _CurveFactor,curve* _CurveFactor,1);
				//eturn fixed4(specular, 1.0);c
				//fixed4 col=fixed4(binormal, 1.0);
				//fixed4 col=fixed4( binormal, 1.0);
				fixed4 col=fixed4( ambient+(diffuse)*rimColor+diffuse+Specular, 1.0);
				return col;
			}
			ENDCG
		}
		
	}
 
	FallBack "Specular"
}

