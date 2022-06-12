Shader "Custom/SSS_normal"{
Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_CurveTex ("CurveMap", 2D) = "white" {}
		_BumpTex ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1.0
		_BumpScatterScale ("Bump Scatter Scale", Float) = 1.0
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_tuneNormalBlur ("tuneNormalBlur", Color) = (1, 1, 1, 1)
		_SSSLUT ("SSSLUT", 2D) = "white" {}
		_SpecularLUT ("BeckmannLUT", 2D) = "white" {}
		_Brightness ("Brightness", Range(0, 1)) = 1
		_Roughness ("Roughness", Range(0, 1)) = 1
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
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile_fog
 
 
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			sampler2D _MainTex;
			sampler2D _CurveTex;
			float4 _MainTex_ST;
			sampler2D _BumpTex;
			sampler2D _SSSLUT;
			sampler2D _SpecularLUT;
			float4 _BumpTex_ST;
			float _BumpScale;
			float _BumpScatterScale;
			fixed4 _Color;
			fixed4 _tuneNormalBlur;
			float _Brightness;
			float _Roughness;
			float _CurveFactor;

			float fresnelReflectance( float3 H, float3 V, float F0 )
			{
				float base = 1.0 - dot( V, H );
				float exponential = pow( base, 5.0 );
				return exponential + F0 * ( 1.0 - exponential );
			}
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
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				float4 pos : CLIP_POS;
				SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex= UnityObjectToClipPos(v.vertex);
				o.pos = UnityObjectToClipPos(v.vertex);
				

				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv.xy, _BumpTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent);
				fixed3 binormal = cross(worldNormal, worldTangent) * v.tangent.w; 
 
				o.TtoW0 = float4(worldTangent.x, binormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, binormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, binormal.z, worldNormal.z, worldPos.z);
				TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}
			

 
			fixed4 frag (v2f i) : SV_Target
			{
				//Basis
				fixed shadow = SHADOW_ATTENUATION(i);
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float3 N_low = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
				float3 tang = float3(i.TtoW0.x, i.TtoW1.x, i.TtoW2.x);
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				fixed3 binormal = cross(N_low, tang) ; 
				i.TtoW0.y=binormal.x;
				i.TtoW1.y=binormal.y;
				i.TtoW2.y=binormal.z;
				
				//SSS NdL
				fixed4 bumpColor = tex2D(_BumpTex, i.uv.zw);
				fixed3 tangentNormal;
				fixed3 tangentSpeculerNormal;
				fixed3 tangentScatterNormal;
				tangentNormal = UnpackNormal(bumpColor);
				tangentSpeculerNormal.xy = tangentNormal*_BumpScale;
				tangentSpeculerNormal.z = normalize(sqrt(1 - saturate(dot(tangentSpeculerNormal.xy, tangentSpeculerNormal.xy))));
				tangentScatterNormal.xy = tangentNormal*_BumpScatterScale;
				tangentScatterNormal.z = normalize(sqrt(1 - saturate(dot(tangentScatterNormal.xy, tangentScatterNormal.xy))));
				float3x3 t2wMatrix = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);
				float3 N_high = half3(mul(t2wMatrix, tangentScatterNormal));
				float3 SpeculerNormal = half3(mul(t2wMatrix, tangentSpeculerNormal));
				float3 rN=lerp(N_high,N_low,_tuneNormalBlur.x);
				float3 gN=lerp(N_high,N_low,_tuneNormalBlur.y);
				float3 bN=lerp(N_high,N_low,_tuneNormalBlur.z);
				float3 NdotL=float3(dot(rN,lightDir),dot(gN,lightDir),dot(bN,lightDir));
				float NoL=dot(normalize(N_high),lightDir);

				//Ambient
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
 
				//SPECULAR
				fixed3 halfDir = normalize(viewDir + lightDir);
				float ndh=dot(normalize(SpeculerNormal), halfDir);
				fixed4 alpha=tex2D(_SpecularLUT,float2(ndh,_Roughness));
				float ph=pow( 2.0*alpha.w, 10.0 );
				float F = fresnelReflectance( halfDir, viewDir, 0.028 );
				float frSpec = max( ph * F / dot( halfDir, halfDir ), 0 );
				float res=_LightColor0.rgb*shadow*saturate(NoL)*_Brightness*frSpec;
				fixed3 specular =fixed3(res,res,res);
				
				//SSS DIFFUSE
				fixed3 diffuseSSS;
				float3 lookup=NdotL*0.5+0.5;
				fixed curve=tex2D(_CurveTex, i.uv.xy).r;
				diffuseSSS.r= tex2D(_SSSLUT,float2(lookup.r,curve* _CurveFactor)).r;
				diffuseSSS.g= tex2D(_SSSLUT,float2(lookup.g,curve* _CurveFactor)).g;
				diffuseSSS.b= tex2D(_SSSLUT,float2(lookup.b,curve* _CurveFactor)).b;
				
				fixed3 diffuse=_LightColor0.rgb * albedo *diffuseSSS  * shadow;
				//diffuse = tex2D(_SSSLUT,float2(NoL*0.5+0.5,cuv));
				//diffuse = fixed4(curve* _CurveFactor,curve* _CurveFactor,curve* _CurveFactor,1);
				//eturn fixed4(specular, 1.0);c
				fixed4 col=fixed4((diffuse+ambient+specular), 1.0);
				return col;
			}
			ENDCG
		}Pass
		{
			Tags  {"LightMode" = "ForwardAdd"}
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			sampler2D _MainTex;
			sampler2D _CurveTex;
			float4 _MainTex_ST;
			sampler2D _BumpTex;
			sampler2D _SSSLUT;
			sampler2D _SpecularLUT;
			float4 _BumpTex_ST;
			float _BumpScale;
			float _BumpScatterScale;
			fixed4 _Color;
			fixed4 _tuneNormalBlur;
			float _Brightness;
			float _Roughness;
			float _CurveFactor;
			float fresnelReflectance( float3 H, float3 V, float F0 )
			{
				float base = 1.0 - dot( V, H );
				float exponential = pow( base, 5.0 );
				return exponential + F0 * ( 1.0 - exponential );
			}
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
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				float4 pos : CLIP_POS;
				SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
			};
 
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex= UnityObjectToClipPos(v.vertex);
				o.pos = UnityObjectToClipPos(v.vertex);

				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv.xy, _BumpTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent);
				fixed3 binormal = cross(worldNormal, worldTangent) * v.tangent.w; 
 
				o.TtoW0 = float4(worldTangent.x, binormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, binormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, binormal.z, worldNormal.z, worldPos.z);
				TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				//Basis
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float3 N_low = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
				float3 tang = float3(i.TtoW0.x, i.TtoW1.x, i.TtoW2.x);
				float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - worldPos.xyz,_WorldSpaceLightPos0.w));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
				fixed3 binormal = cross(N_low, tang) ; 
				i.TtoW0.y=binormal.x;
				i.TtoW1.y=binormal.y;
				i.TtoW2.y=binormal.z;

					//SSS NdL
				fixed4 bumpColor = tex2D(_BumpTex, i.uv.zw);
				fixed3 tangentNormal;
				fixed3 tangentSpeculerNormal;
				fixed3 tangentScatterNormal;
				tangentNormal = UnpackNormal(bumpColor);
				tangentSpeculerNormal.xy = tangentNormal*_BumpScale;
				tangentSpeculerNormal.z = normalize(sqrt(1 - saturate(dot(tangentSpeculerNormal.xy, tangentSpeculerNormal.xy))));
				tangentScatterNormal.xy = tangentNormal*_BumpScatterScale;
				tangentScatterNormal.z = normalize(sqrt(1 - saturate(dot(tangentScatterNormal.xy, tangentScatterNormal.xy))));
				float3x3 t2wMatrix = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);
				float3 N_high = half3(mul(t2wMatrix, tangentScatterNormal));
				float3 SpeculerNormal = half3(mul(t2wMatrix, tangentSpeculerNormal));
				float3 rN=lerp(N_high,N_low,_tuneNormalBlur.x);
				float3 gN=lerp(N_high,N_low,_tuneNormalBlur.y);
				float3 bN=lerp(N_high,N_low,_tuneNormalBlur.z);
				float3 NdotL=float3(dot(rN,lightDir),dot(gN,lightDir),dot(bN,lightDir));
				float NoL=dot(normalize(N_high),lightDir);

				//SPECULAR
				fixed3 halfDir = normalize(viewDir + lightDir);
				float ndh=dot(normalize(SpeculerNormal), halfDir);
				fixed4 alpha=tex2D(_SpecularLUT,float2(ndh,_Roughness));
				float ph=pow( 2.0*alpha.w, 10.0 );
				float F = fresnelReflectance( halfDir, viewDir, 0.028 );
				float frSpec = max( ph * F / dot( halfDir, halfDir ), 0 );
				float res=_LightColor0.rgb*saturate(NoL)*_Brightness*frSpec;
				fixed3 specular =fixed3(res,res,res);
				
				//SSS DIFFUSE
				fixed3 diffuseSSS;
				float3 lookup=NdotL*0.5+0.5;
				fixed curve=tex2D(_CurveTex, i.uv.xy).r;
				diffuseSSS.r= tex2D(_SSSLUT,float2(lookup.r,curve* _CurveFactor)).r;
				diffuseSSS.g= tex2D(_SSSLUT,float2(lookup.g,curve* _CurveFactor)).g;
				diffuseSSS.b= tex2D(_SSSLUT,float2(lookup.b,curve* _CurveFactor)).b;
				
				fixed3 diffuse=_LightColor0.rgb * albedo *diffuseSSS;



				UNITY_LIGHT_ATTENUATION(attenuation,i, worldPos.xyz);
				
				fixed4 col=fixed4((diffuse+specular)*attenuation, 1.0);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
 
	FallBack "Specular"
}

