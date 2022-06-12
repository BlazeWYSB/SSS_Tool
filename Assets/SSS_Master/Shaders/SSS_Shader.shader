// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/SSS_Shader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_BumpTex ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1.0
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SSSLUT ("SSSLUT", 2D) = "white" {}
		_Gloss ("Gloss", Range(8.0, 256)) = 20
		_CurveFactor("CurveRate",Range(1,500))=1
	}
	SubShader
	{
		Pass
		{
			Tags  {"LightMode" = "ForwardBase"}
 
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
 
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpTex;
			sampler2D _SSSLUT;
			float4 _BumpTex_ST;
			float _BumpScale;
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
				float4 vertex : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				float3 Cnormal : TEXCOORD4;
			};
 
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
 
				o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv.xy, _BumpTex);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent);
				fixed3 binormal = cross(worldNormal, worldTangent) * v.tangent.w; 
 
				o.TtoW0 = float4(worldTangent.x, binormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, binormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, binormal.z, worldNormal.z, worldPos.z);
				o.Cnormal=v.normal;
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
 
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
 
				fixed4 bumpColor = tex2D(_BumpTex, i.uv.zw);
				fixed3 tangentNormal;
//				tangentNormal.xy = (bumpColor.xy * 2 - 1) * _BumpScale;
//				tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				tangentNormal = UnpackNormal(bumpColor);
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
 
				float3x3 t2wMatrix = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);
				tangentNormal = normalize(half3(mul(t2wMatrix, tangentNormal)));
 
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;
 
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo+fixed3(0.2,0.2,0.2);
 
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, lightDir));
 
				fixed3 halfDir = normalize(viewDir + lightDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

				//曲率
				float3 worldBump = normalize(i.Cnormal);
				float NoL=dot(worldBump,lightDir);
				float cuv =saturate( length(fwidth(worldBump)) / length(fwidth(worldPos)) / 100 * _CurveFactor);
				diffuse = _LightColor0.rgb * albedo *tex2D(_SSSLUT,float2(NoL*0.5+0.5,cuv));
				//diffuse = tex2D(_SSSLUT,float2(NoL*0.5+0.5,cuv));
				//diffuse = fixed4(cuv,cuv,cuv,1);
				return fixed4(ambient + diffuse + specular, 1.0);
				return fixed4(ambient + diffuse , 1.0);
			}
			ENDCG
		}
	}
 
	FallBack "Specular"
}
