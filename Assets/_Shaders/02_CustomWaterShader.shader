﻿Shader "Unlit/02_CustomWaterShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		//Tags { "RenderType"="Opaque" }
		Tags{ "Queue" = "Transparent" "RenderType"="Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
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
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

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
						
			float pNoise(float2 P) // Classic Perlin noise
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
			////End Helper Functions
			
			////Shaders
			v2f vert (appdata v)
			{
				v2f o;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex;
				o.normal = v.normal;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			[maxvertexcount(76)]
			void geom(triangle v2f input[3], inout TriangleStream<v2f> OutputStream)
            {					
				float3 AB = input[1].vertex.xyz - input[0].vertex.xyz, AC = input[2].vertex.xyz - input[0].vertex.xyz, BC = input[2].vertex.xyz - input[1].vertex.xyz;

				//DEBUG
				float3 col;

				float3 perp, diag, bisc;
				if(length(AB) >= length(AC) && length(AB) >= length(BC))
				{
					col = float3(0.2, 0.05, 0.85); //purple

					diag = input[0].vertex.xyz;
					perp = input[2].vertex.xyz;

					bisc = lerp(input[0].vertex.xyz, input[2].vertex.xyz, 0.5);
				}
				else if(length(AC) >= length(AB) && length(AC) >= length(BC))
				{
					col = float3(0.85, 0.05, 0.2); //pink

					diag = input[0].vertex.xyz;
					perp = input[1].vertex.xyz;

					bisc = lerp(input[0].vertex.xyz, input[1].vertex.xyz, 0.5);
				}
				else 
				{
					col = float3(1.0, 1.0, 1.0);

					diag = input[1].vertex.xyz;
					perp = input[0].vertex.xyz;

					bisc = lerp(input[1].vertex.xyz, input[0].vertex.xyz, 0.5);
				}

				diag = normalize(diag);
				perp = normalize(perp);
				bisc = normalize(bisc);
				
				//Build pie strips
				bool foldSpace = (dot(perp, float3(0.0, 0.0, 1.0)) > 0.0);
				if (foldSpace)
				{
					//rotate diag, perp, bisc, biscB, 180 around y
					diag = rotateVertexPosition(diag, float3(0.0, 1.0, 0.0), 225.0);
					perp = rotateVertexPosition(perp, float3(0.0, 1.0, 0.0), 225.0);
					bisc = rotateVertexPosition(bisc, float3(0.0, 1.0, 0.0), 225.0);
				}

				v2f generated = (v2f)0;				
				for(int i = 0; i < 4; i++) //i == pie strip index
				{
					//generate center vertex
					generated.vertex = float4(0.0, 0.0, 0.0, 1.0);
					//find wave height...
					//find normal...
					generated.normal = col;
					generated.uv = float2(0.0, 0.0);
					generated.vertex = UnityObjectToClipPos(generated.vertex); //transform vertex to screen space
					OutputStream.Append(generated);

					float3 sideA = rotateVertexPosition(diag, float3(0.0, 1.0, 0.0), i * 45.0);
					float3 sideB = rotateVertexPosition(bisc, float3(0.0, 1.0, 0.0), i * 45.0);		
					
					if(foldSpace)
					{
						float3 tmp = sideB;
						sideB = sideA;
						sideA = tmp;
					}

					for(int j = 1; j <= 8; j++) //j == pie strip segment index
					{
						generated.vertex = float4(sideA.x * (1.0 * pow(2.0, j)), sideA.y * (1.0 * pow(2.0, j)), sideA.z * (1.0 * pow(2.0, j)), 1.0);
						//find wave height...
						//find normal...
						generated.normal = col;
						generated.uv = generated.vertex.xz;
						generated.vertex = UnityObjectToClipPos(generated.vertex); //transform vertex to screen space
						OutputStream.Append(generated);

						generated.vertex = float4(sideB.x * (1.0 * pow(2.0, j)), sideB.y * (1.0 * pow(2.0, j)), sideB.z * (1.0 * pow(2.0, j)), 1.0);
						//find wave height...
						//find normal...
						generated.normal = col;
						generated.uv = generated.vertex.xz;
						generated.vertex = UnityObjectToClipPos(generated.vertex); //transform vertex to screen space
						OutputStream.Append(generated);
					}

					OutputStream.RestartStrip();
				}				
            }
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv) * fixed4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				//fixed4 col = fixed4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
			////End Shaders
		}
	}
}
