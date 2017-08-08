Shader "Unlit/01_BasicBumpMapTestShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_BumpMap ("Bump Map", 2D) = "bump" {}
		_Light ("Light Direction", Vector) = (50.0, -30.0, 0.0)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Tags { "LightMode"="ForwardBase" } 

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			// make shadows work
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
			
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				LIGHTING_COORDS(2, 3)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float3 _Light;

			////Helper Functions
			//Light
			float GetLightIntensity (float3 normal, float attenuation)
			{
				//I == A + S * (D * dot(N,L) + pow(dot(R, V), n))
				//L == direction to light (normalized)
				//V == direction to camera (normalized)				
				//N == normal from vertex
				//R == reflection
				//n == shininess

				//need diffuse constant
				float4 diffuse = {1.0f, 0.0f, 0.0f, 1.0f}; //temp
				
				//float4 ambient = (float4)(UNITY_LIGHTMODEL_AMBIENT * 2);
				float4 ambient = { 0.1f, 0.0f, 0.0f, 1.0f};

				float3 norm = normalize(normal);

				//float3 lightDir = float3(cos(_Light.y)*cos(_Light.x), sin(_Light.y)*cos(_Light.x), sin(_Light.x));
				float3 lightDir = float3(sin(_Light.y)*cos(_Light.x), cos(_Light.y)*cos(_Light.x), sin(_Light.x));
				lightDir = mul(unity_WorldToObject, lightDir);

				float3 viewDir = normalize(mul(float3(0.0, 0.0, 0.0), unity_ObjectToWorld) - _WorldSpaceCameraPos); //may need to add "mul(float3(0.0, 0.0, 0.0), unity_ObjectToWorld)" 

				float4 diff = saturate(dot(norm, lightDir)) * attenuation; // diffuse component 

				// compute self-shadowing term
				float shadow = saturate(4 * diff);

				float3 reflect = normalize(2 * diff * norm - lightDir); // R
				float4 specular = pow(saturate(dot(reflect, viewDir)), 8); // pow(dot(R, V), n)
				
				return (ambient + shadow * (diffuse * diff + specular)) * 2;				
			}
			////End Helper Functions
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.pos);
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float attenuation = LIGHT_ATTENUATION(i);

				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);

				//float3 bumpNorm = tex2D(_BumpMap, i.uv);
				float3 bumpNorm = UnpackNormal(tex2D(_BumpMap, i.uv));

				//fixed4 col = fixed4(bumpNorm.r, bumpNorm.g, bumpNorm.b, 1.0);
				//fixed4 col = fixed4(1.0, 1.0, 1.0, 1.0);

				col.rgb *= GetLightIntensity(bumpNorm, attenuation);

				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}
