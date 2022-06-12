Shader "Custom/Origin"{
Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_CurveTex ("CurveMap", 2D) = "white" {}
		_BumpTex ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1.0
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
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
			#pragma multi_compile_fwdbase
			//#include "Lighting.cginc"
 
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
			fixed4 _Color;
			fixed4 _Specular;
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
				float4 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
				SHADOW_COORDS(4)
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
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
				return o;
			}
			

 
			fixed4 frag (v2f i) : SV_Target
			{
				//Basis
				fixed shadow = SHADOW_ATTENUATION(i);
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float3 N_low = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				//SSS NdL
				fixed4 bumpColor = tex2D(_BumpTex, i.uv.zw);
				fixed3 tangentNormal;
				tangentNormal = UnpackNormal(bumpColor);
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = normalize(sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy))));
				float3x3 t2wMatrix = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);
				float3 N_high = half3(mul(t2wMatrix, tangentNormal));
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
				float ndh=dot(normalize(N_high), halfDir);
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
				//diffuseSSS.r= tex2D(_SSSLUT,float2(lookup.r,curve* _CurveFactor)).r;
				//diffuseSSS.g= tex2D(_SSSLUT,float2(lookup.g,curve* _CurveFactor)).g;
				//diffuseSSS.b= tex2D(_SSSLUT,float2(lookup.b,curve* _CurveFactor)).b;
				diffuseSSS=lookup.x;
				fixed3 diffuse=_LightColor0.rgb * albedo *diffuseSSS  * shadow;
				//diffuse = tex2D(_SSSLUT,float2(NoL*0.5+0.5,cuv));
				//diffuse = fixed4(curve* _CurveFactor,curve* _CurveFactor,curve* _CurveFactor,1);
				//eturn fixed4(specular, 1.0);
				return fixed4(diffuse+ambient+specular, 1.0);
			}
			ENDCG
		}Pass
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
			sampler2D _BumpTex;
			sampler2D _SSSLUT;
			sampler2D _SpecularLUT;
			float4 _BumpTex_ST;
			float _BumpScale;
			fixed4 _Color;
			fixed4 _Specular;
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
				float4 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 TtoW0 : TEXCOORD1;
				float4 TtoW1 : TEXCOORD2;
				float4 TtoW2 : TEXCOORD3;
			};
 
			v2f vert (appdata v)
			{
				v2f o;
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
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				//Basis
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				float3 N_low = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下可以直接获取世界空间下的光照方向
					fixed3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				#else  //其他光源下_WorldSpaceLightPos0代表光源的世界坐标，与顶点的世界坐标的向量相减可得到世界空间下的光照方向
					fixed3 lightDir = normalize(_WorldSpaceLightPos0.xyz - worldPos.xyz);
				#endif
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;

				//SSS NdL
				fixed4 bumpColor = tex2D(_BumpTex, i.uv.zw);
				fixed3 tangentNormal;
				tangentNormal = UnpackNormal(bumpColor);
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = normalize(sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy))));
				float3x3 t2wMatrix = float3x3(i.TtoW0.xyz, i.TtoW1.xyz, i.TtoW2.xyz);
				float3 N_high = half3(mul(t2wMatrix, tangentNormal));
				float3 rN=lerp(N_high,N_low,_tuneNormalBlur.x);
				float3 gN=lerp(N_high,N_low,_tuneNormalBlur.y);
				float3 bN=lerp(N_high,N_low,_tuneNormalBlur.z);
				float3 NdotL=float3(dot(rN,lightDir),dot(gN,lightDir),dot(bN,lightDir));
				float NoL=dot(normalize(N_high),lightDir);
 
				//SPECULAR
				fixed3 halfDir = normalize(viewDir + lightDir);
				float ndh=dot(normalize(N_high), halfDir);
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



				#ifdef USING_DIRECTIONAL_LIGHT  //平行光下不存在光照衰减，恒值为1
					fixed atten = 1.0;
				#else
					#if defined (POINT)    //点光源的光照衰减计算
						//unity_WorldToLight内置矩阵，世界空间到光源空间变换矩阵。与顶点的世界坐标相乘可得到光源空间下的顶点坐标
						float3 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1)).xyz;
						//利用Unity内置函数tex2D对Unity内置纹理_LightTexture0进行纹理采样计算光源衰减，获取其衰减纹理，
						//再通过UNITY_ATTEN_CHANNEL得到衰减纹理中衰减值所在的分量，以得到最终的衰减值
						fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
					#elif defined (SPOT)   //聚光灯的光照衰减计算
						float4 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1));
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
