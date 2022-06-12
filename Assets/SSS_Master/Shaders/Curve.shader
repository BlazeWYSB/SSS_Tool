Shader "Custom/Curve"
{
    Properties
	{
		
		_CurveFactor("CurveRate",Range(0,10))=1
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
				float3 wpos : TEXCOORD1;
				float3 Cnormal : TEXCOORD2;
			};
 
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.wpos=worldPos;
				o.Cnormal=v.normal;
				return o;
			}
 
			fixed4 frag (v2f i) : SV_Target
			{
				//曲率
				float3 worldBump = normalize(i.Cnormal);
				float cuv =saturate( length(fwidth(worldBump)) / length(fwidth(i.wpos)) / 100 * _CurveFactor);
				fixed4 diffuse = fixed4(cuv,cuv,cuv,1);
				return diffuse;
			}
			ENDCG
		}
	}
 
	FallBack "Specular"
}
