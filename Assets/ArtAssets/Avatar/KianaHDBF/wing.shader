Shader "Unlit/wing"
{
    Properties
    {
        [HDR]_Color ("Color",color)=(1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Mask", 2D) = "white" {}
        _WaveSpeed("贴图移速",float)=3
 
    }
    SubShader
    {
        Blend One ONE
        CULL OFF
        Tags{"Queue"="Transparent"}
 
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
 
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
 
 
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            //下面是顶点着色器，有四个可控量，控制振幅、波长、频率、偏移
            float _Frequency;
            float _Attruibte; 
            float _K2;
            float _B2;
            fixed3 _Color;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            //下面是片段着色器 控制像素的移动
            sampler2D _MainTex;
            sampler2D _MaskTex;
            float _WaveSpeed;
            fixed4 frag (v2f i) : SV_Target
            {
                float2 tmpUV=i.uv;
                tmpUV.y+= _WaveSpeed*_Time.y;
                //tmpUV.x+=_WaveSpeed*_Time.x;
                fixed4 col = tex2D(_MaskTex,tmpUV);
                fixed4 col2 = tex2D(_MainTex,i.uv);
                return fixed4(_Color,1)*(col+col2);
            }
            ENDCG
        }
    }
}