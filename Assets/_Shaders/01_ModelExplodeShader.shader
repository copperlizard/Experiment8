// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/01_ModelExplodeShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", color) = (1, 1, 1, 1)
	}
	SubShader
	{
		//Tags { "RenderType"="Opaque" }
		Tags{ "Queue" = "Transparent" "RenderType"="Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
				float4 worldPosition : TEXCOORD1;	
				UNITY_FOG_COORDS(1)	
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;

			v2f vert (appdata v)
			{
				v2f o;
				o.worldPosition = v.vertex;
				o.normal = v.normal;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			[maxvertexcount(3)]
            void geom(triangle v2f input[3], inout TriangleStream<v2f> OutputStream)
            {
                v2f generated = (v2f)0;
                float3 normal = normalize(cross(input[1].worldPosition.xyz - input[0].worldPosition.xyz, input[2].worldPosition.xyz - input[0].worldPosition.xyz));
                for(int i = 0; i < 3; i++)
                {
					generated.normal = normal;
					
					//float l = sqrt(input[i].vertex.y * input[i].vertex.y + input[i].vertex.y * input[i].vertex.y);
					float l = cos(input[i].vertex.x * 5.0 + _Time.x * 3.0) * cos(input[i].vertex.y * 5.0  + _Time.x * 5.0) * cos(input[i].vertex.z * 5.0  + _Time.x * 2.0); // * smoothstep(0.0, 1.0, input[i].vertex.y)
					generated.vertex = UnityObjectToClipPos(input[i].vertex + float4(normal.x, normal.y, normal.z, 0.0) * (0.1 + 0.2 * l * cos(_Time.x * 5.0)));

					generated.uv = input[i].uv;
                    OutputStream.Append(generated);
                }
            }
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv) * _Color;
				fixed4 col = _Color;
				
				//fixed4 col = float4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
