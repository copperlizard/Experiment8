Shader "Unlit/03_CustomWaterShader"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Texture", 2D) = "white" {}
		_BumpMap ("Bump Map", 2D) = "bump" {}
		_Light ("Light Direction", Vector) = (50.0, -30.0, 0.0)
		_WaveAmplitude ("WaveAmplitude", float) = 0.25
		_NormalScanTriSideLength ("NormalScanTriSideLength", float) = 0.1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		Blend SrcAlpha OneMinusSrcAlpha
		LOD 100

		Pass
		{
			//Tags { "LightMode"="ForwardBase" }

			CGPROGRAM

			// Use shader model 3.0 target, to get nicer looking lighting
			//#pragma target 3.0
			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			// make shadows work
			//#pragma multi_compile_fwdbase
			
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
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 pos : TEXCOORD1;
				float3 normal : TEXCOORD2;
				UNITY_FOG_COORDS(3)
				LIGHTING_COORDS(4, 5)
			};

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			float3 _Light;
			float _WaveAmplitude;
			float _NormalScanTriSideLength;

			////Helper Functions

			//Quaterions
			float4 quatFromAxisAngle(float3 axis, float angle)
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
			}

			//Noise
			float rand(float2 c) 
			{
				return frac(sin(dot(c.xy, float2(12.9898, 78.233))) * 43758.5453);
			}	

			float4 mod289(float4 x)
			{
				return x - floor(x * (1.0 / 289.0)) * 289.0;
			}

			float4 permute(float4 x)
			{
				return mod289(((x*34.0) + 1.0)*x);
			}

			float4 taylorInvSqrt(float4 r)
			{
				return 1.79284291400159 - 0.85373472095314 * r;
			}

			float2 fade(float2 t) {
				return t*t*t*(t*(t*6.0 - 15.0) + 10.0);
			}
						
			float PerlinNoise(float2 P) // Classic Perlin noise
			{
				float4 Pi = floor(P.xyxy) + float4(0.0, 0.0, 1.0, 1.0);
				float4 Pf = frac(P.xyxy) - float4(0.0, 0.0, 1.0, 1.0);
				Pi = mod289(Pi); // To avoid truncation effects in permutation
				float4 ix = Pi.xzxz;
				float4 iy = Pi.yyww;
				float4 fx = Pf.xzxz;
				float4 fy = Pf.yyww;

				float4 i = permute(permute(ix) + iy);

				float4 gx = frac(i * (1.0 / 41.0)) * 2.0 - 1.0;
				float4 gy = abs(gx) - 0.5;
				float4 tx = floor(gx + 0.5);
				gx = gx - tx;

				float2 g00 = float2(gx.x, gy.x);
				float2 g10 = float2(gx.y, gy.y);
				float2 g01 = float2(gx.z, gy.z);
				float2 g11 = float2(gx.w, gy.w);

				float4 norm = taylorInvSqrt(float4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
				g00 *= norm.x;
				g01 *= norm.y;
				g10 *= norm.z;
				g11 *= norm.w;

				float n00 = dot(g00, float2(fx.x, fy.x));
				float n10 = dot(g10, float2(fx.y, fy.y));
				float n01 = dot(g01, float2(fx.z, fy.z));
				float n11 = dot(g11, float2(fx.w, fy.w));

				float2 fade_xy = fade(Pf.xy);
				float2 n_x = lerp(float2(n00, n01), float2(n10, n11), fade_xy.x);
				float n_xy = lerp(n_x.x, n_x.y, fade_xy.y);
				return 2.3 * n_xy;
			}

			//Water
			float3 FindWaterNormal (float3 pos)
			{	
				//Draw triangle around point, find triangle normal... 
				float halfH = ((_NormalScanTriSideLength * 1.73205)/2.0)/2.0;
				float3 m = pos - float3(0.0, 0.0, halfH);
				float3 p1 = pos + float3(0.0, 0.0, halfH);
				float3 p2 = m + float3(_NormalScanTriSideLength * 0.5, 0.0, 0.0);
				float3 p3 = m - float3(_NormalScanTriSideLength * 0.5, 0.0, 0.0);

				//wave height....
				p1.y += _WaveAmplitude * PerlinNoise(p1.xz * 0.25 + _Time.xx); 
				p2.y += _WaveAmplitude * PerlinNoise(p2.xz * 0.25 + _Time.xx);
				p3.y += _WaveAmplitude * PerlinNoise(p3.xz * 0.25 + _Time.xx);

				float3 p1p2 = p2 - p1, p1p3 = p3 - p1;

				return normalize(cross(normalize(p1p2), normalize(p1p3)));
			}

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

			////Shaders
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = v.vertex;
				o.pos.y += _WaveAmplitude * PerlinNoise(o.pos.xz * 0.25 + _Time.xx * 2.5);
				o.normal = FindWaterNormal(o.pos);
				o.vertex = UnityObjectToClipPos(o.pos);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float attenuation = LIGHT_ATTENUATION(i);
				float3 bumpNorm = UnpackNormal(tex2D(_BumpMap, i.uv + _Time.xx * 0.05));
				float3 surfNorm = FindWaterNormal(i.pos);

				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv + _Time.xx * 0.05) * _Color;
				//col.xyz *= GetLightIntensity(i.normal, attenuation);
				col.xyz *= GetLightIntensity(lerp(bumpNorm, surfNorm, 0.75), attenuation);
				
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
			////End Shaders
		}
	}
	//Fallback "Diffuse"
}
