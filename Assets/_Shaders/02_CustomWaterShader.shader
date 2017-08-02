Shader "Unlit/02_CustomWaterShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Light ("Light Direction", Vector) = (50.0, -30.0, 0.0)
		_MaxWaveHeight ("MaxWaveHeight", float) = 0.25
		_NormalScanTriSideLength ("NormalScanTriSideLength", float) = 0.1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		//Tags{ "Queue" = "Transparent" "RenderType"="Transparent" }
		//Blend SrcAlpha OneMinusSrcAlpha
		LOD 100

		Pass
		{
			Tags { "LightMode"="ForwardBase" }

			CGPROGRAM

			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			
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
				//float2 uv : TEXCOORD0;
			};

			struct v2f
			{							
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float depth : DEPTH;
				//float2 uv : TEXCOORD0;	//too many components for geometry shader...
				UNITY_FOG_COORDS(0)
				LIGHTING_COORDS(1, 2)
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float3 _Light;
			float _MaxWaveHeight;
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
				float triSideLength = 5.0; //changes length of normal???
				float halfH = ((triSideLength * 1.73205)/2.0)/2.0;
				float3 m = pos - float3(0.0, 0.0, halfH);
				float3 p1 = pos + float3(0.0, 0.0, halfH);
				float3 p2 = m + float3(_NormalScanTriSideLength * 0.5, 0.0, 0.0);
				float3 p3 = m - float3(_NormalScanTriSideLength * 0.5, 0.0, 0.0);

				//wave height....
				p1.y += _MaxWaveHeight * PerlinNoise(p1.xz) * 500.0; 
				p2.y += _MaxWaveHeight * PerlinNoise(p2.xz) * 500.0;
				p3.y += _MaxWaveHeight * PerlinNoise(p3.xz) * 500.0;

				float3 p1p2 = p2 - p1, p1p3 = p3 - p1;

				return normalize(cross(normalize(p1p2), normalize(p1p3)));
			}

			//Light
			/*float GetLightIntensity (float3 normal)
			{
				//I == A + S * (D * dot(N,L) + pow(dot(R, V), N))

				//L == direction to light (normalized)

				//V == direction to camera (normalized)
				
				//N == normal from vertex

				//R == reflection

				//need ambient constant

				//need diffuse constant
				float4 diffuse = { 1.0f, 0.0f, 0.0f, 1.0f}; //temp
				float4 ambient = {0.1, 0.0, 0.0, 1.0}; //temp

				float3 norm = normalize(normal);

				//float3 lightDir = normalize(float3(0.5, 0.5, 0.0));

				float3 lightDir = float3(0.0, 1.0, 0.0);
				lightDir = rotateVertexPosition(lightDir, float3(1.0, 0.0, 0.0), _Light.x);
				lightDir = rotateVertexPosition(lightDir, float3(0.0, 1.0, 0.0), _Light.y);

				float3 viewDir = normalize(_WorldSpaceCameraPos); //may need to add "mul(float3(0.0, 0.0, 0.0), unity_ObjectToWorld)" 

				float4 diff = saturate(dot(norm, lightDir)); // diffuse component

				// compute self-shadowing term
				float shadow = saturate(4 * diff);

				float3 reflect = normalize(2 * diff * norm - lightDir); // R
				//float4 specular = pow(saturate(dot(reflect, viewDir)), 8); // R.V^n
				// I = ambient + shadow * (Dcolor * N.L + (R.V)n)
				//return ambient + shadow * (diffuse * diff + specular); 
				return ambient + shadow * (diffuse * diff); 
			}*/

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

			////End Helper Functions
			
			////Shaders
			v2f vert (appdata v)
			{
				v2f o;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = v.vertex;
				o.normal = v.normal;
				//o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z *_ProjectionParams.w;
				o.depth = UnityObjectToViewPos(v.vertex);
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}

			[maxvertexcount(76)]
			void geom(triangle v2f input[3], inout TriangleStream<v2f> OutputStream)
            {					
				float3 AB = input[1].pos.xyz - input[0].pos.xyz, AC = input[2].pos.xyz - input[0].pos.xyz, BC = input[2].pos.xyz - input[1].pos.xyz;

				//DEBUG
				float3 col;

				float3 perp, diag, bisc;
				if(length(AB) >= length(AC) && length(AB) >= length(BC))
				{
					col = float3(0.2, 0.05, 0.85); //purple

					diag = input[0].pos.xyz;
					perp = input[2].pos.xyz;

					bisc = lerp(input[0].pos.xyz, input[2].pos.xyz, 0.5);
				}
				else if(length(AC) >= length(AB) && length(AC) >= length(BC))
				{
					col = float3(0.85, 0.05, 0.2); //pink

					diag = input[0].pos.xyz;
					perp = input[1].pos.xyz;

					bisc = lerp(input[0].pos.xyz, input[1].pos.xyz, 0.5);
				}
				else 
				{
					col = float3(1.0, 1.0, 1.0);

					diag = input[1].pos.xyz;
					perp = input[0].pos.xyz;

					bisc = lerp(input[1].pos.xyz, input[0].pos.xyz, 0.5);
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
					generated.pos = float4(0.0, 0.0, 0.0, 1.0);
										
					generated.normal = FindWaterNormal(generated.pos.xyz * 500.0 + _Time.xxx * 5.0); //find normal...
					
					generated.pos.y += _MaxWaveHeight * PerlinNoise(generated.pos.xz * 500.0 + _Time.xx * 5.0);	//find wave height at vertex...					
					
					//generated.uv = float2(0.0, 0.0);

					generated.pos = UnityObjectToClipPos(generated.pos); //transform vertex to screen space
					TRANSFER_VERTEX_TO_FRAGMENT(generated);
					UNITY_TRANSFER_FOG(generated,generated.pos);
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
						generated.pos = float4(sideA.x * (0.0019 * pow(2.0, j)), sideA.y * (0.0019 * pow(2.0, j)), sideA.z * (0.0019 * pow(2.0, j)), 1.0);
						
						generated.normal = FindWaterNormal(generated.pos.xyz * 500.0 + _Time.xxx * 5.0); //find normal...
						
						generated.pos.y += _MaxWaveHeight * PerlinNoise(generated.pos.xz * 500.0 + _Time.xx * 5.0);	//find wave height at vertex...					
						
						//generated.uv = generated.vertex.xz * 500.0;
						
						generated.pos = UnityObjectToClipPos(generated.pos); //transform vertex to screen space
						TRANSFER_VERTEX_TO_FRAGMENT(generated);
						UNITY_TRANSFER_FOG(generated,generated.pos);
						OutputStream.Append(generated);

						generated.pos = float4(sideB.x * (0.0019 * pow(2.0, j)), sideB.y * (0.0019 * pow(2.0, j)), sideB.z * (0.0019 * pow(2.0, j)), 1.0);
						
						generated.normal = FindWaterNormal(generated.pos.xyz * 500.0 + _Time.xxx * 5.0); //find normal...
						
						generated.pos.y += _MaxWaveHeight * PerlinNoise(generated.pos.xz * 500.0 + _Time.xx * 5.0); //find wave height at vertex...
						
						//generated.uv = generated.vertex.xz * 500.0;
						
						generated.pos = UnityObjectToClipPos(generated.pos); //transform vertex to screen space
						TRANSFER_VERTEX_TO_FRAGMENT(generated);
						UNITY_TRANSFER_FOG(generated,generated.pos);
						OutputStream.Append(generated);
					}

					OutputStream.RestartStrip();
				}				
            }
			
			fixed4 frag (v2f i) : SV_Target
			{	
				float attenuation = LIGHT_ATTENUATION(i);

				float4 worldPos = mul(unity_CameraInvProjection, i.pos);


				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv) * fixed4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				//fixed4 col = tex2D(_MainTex, worldPos.xz * 500.0);

				//fixed4 col = fixed4(0.3, 0.05, 0.7, 1.0);
				fixed4 col = fixed4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				
				
				//col.xyz *= GetLightIntensity(i.normal, attenuation);
				
				

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
