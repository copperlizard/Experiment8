// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Unlit/01_BasicLightTestShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
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
			
			// Use shader model 3.0 target, to get nicer looking lighting
			#pragma target 3.0
			#pragma fragmentoption ARB_precision_hint_fastest

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
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{	
				float4 pos : SV_POSITION;
				float3 normal : TEXCOORD1;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(2)
				LIGHTING_COORDS(3, 4)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float3 _Light;
			
			//Helper Functions

			//Quaterions
			/*float4 quatFromAxisAngle(float3 axis, float angle)
			{ 
				float4 qr;
				float half_angle = (angle * 0.5) * 3.14159 / 180.0;
				qr.x = axis.x * sin(half_angle);
				qr.y = axis.y * sin(half_angle);
				qr.z = axis.z * sin(half_angle);
				qr.w = cos(half_angle);
				return qr;
			}

			float4 quatConj(float4 q)
			{ 
				return float4(-q.x, -q.y, -q.z, q.w); 
			}
  
			float4 quatMult(float4 q1, float4 q2)
			{ 
				float4 qr;
				qr.x = (q1.w * q2.x) + (q1.x * q2.w) + (q1.y * q2.z) - (q1.z * q2.y);
				qr.y = (q1.w * q2.y) - (q1.x * q2.z) + (q1.y * q2.w) + (q1.z * q2.x);
				qr.z = (q1.w * q2.z) + (q1.x * q2.y) - (q1.y * q2.x) + (q1.z * q2.w);
				qr.w = (q1.w * q2.w) - (q1.x * q2.x) - (q1.y * q2.y) - (q1.z * q2.z);
				return qr;
			}

			float3 rotateVertexPosition(float3 position, float3 axis, float angle)
			{ 
				float4 qr = quatFromAxisAngle(axis, angle);
				float4 qrConj = quatConj(qr);
				float4 qPos = float4(position.x, position.y, position.z, 0);
  
				float4 qTmp = quatMult(qr, qPos);
				qr = quatMult(qTmp, qrConj);
  
				return float3(qr.x, qr.y, qr.z);
			}*/

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

				float3 lightDir = float3(cos(_Light.y)*cos(_Light.x), sin(_Light.y)*cos(_Light.x), sin(_Light.x));
				//float3 lightDir = float3(1.0, 0.0, 0.0);
				lightDir = mul(unity_WorldToObject, lightDir);

				float3 viewDir = normalize(mul(float3(0.0, 0.0, 0.0), unity_ObjectToWorld) - _WorldSpaceCameraPos); //may need to add "mul(float3(0.0, 0.0, 0.0), unity_ObjectToWorld)" 

				float4 diff = saturate(dot(norm, lightDir)) * attenuation; // diffuse component

				// compute self-shadowing term
				float shadow = saturate(4 * diff);

				float3 reflect = normalize(2 * diff * norm - lightDir); // R
				float4 specular = pow(saturate(dot(reflect, viewDir)), 8); // pow(dot(R, V), n)
				
				return (ambient + shadow * (diffuse * diff + specular)) * 2;				
			}
			//End Helper Functions

			//Shaders
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = v.normal;				
				
				UNITY_TRANSFER_FOG(o,o.pos);		
				
				TRANSFER_VERTEX_TO_FRAGMENT(o);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{	
				float attenuation = LIGHT_ATTENUATION(i);

				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);	
				//col.rgb += attenuation * 2;
				col.rgb *= GetLightIntensity(i.normal, attenuation);
				
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
			//End Shaders
		}
	}
	Fallback "Diffuse"
}
