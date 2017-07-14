Shader "Unlit/01_CustomWaterShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_TriangulationSteps ("TriangulationSteps", Int) = 3
		_ScreenWidth ("ScreenWidth", float) = 1920.0
		_MaxWaveHeight ("MaxWaveHeight", float) = 0.25
	}
	SubShader
	{
		Tags{ "Queue" = "Transparent" "RenderType"="Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		//Cull Off
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
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				//float4 worldPosition : TEXCOORD1; //using vertex as world pos...
				float3 normal : NORMAL;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			int _TriangulationSteps;
			float _ScreenWidth;
			float _MaxWaveHeight;

			v2f vert (appdata v)
			{
				v2f o;
				//o.worldPosition = v.vertex;
				o.normal = v.normal;
				//o.vertex = UnityObjectToClipPos(v.vertex);
				o.vertex = v.vertex;
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}

			//Geometry shader helper functions

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

			// Classic Perlin noise
			float pNoise(float2 P)
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

			float FindWaveHeight (float3 pos)
			{
				return pNoise(pos.xz * 100.0 + _Time.xy * 0.5); //_Time.xy * 0.5
			}

			float3 FindNormal (float3 pos)
			{
				pos.y = 0.0;
				float3 p1 = pos + float3(1.0, 0.0, 0.0), p2 = pos + float3(0.0, 0.0, -1.0), p3 = pos + float3(-1.0, 0.0, 0.0), p4 = pos + float3(0.0, 0.0, 1.0);

				p1.y += _MaxWaveHeight * FindWaveHeight(p1);
				p2.y += _MaxWaveHeight * FindWaveHeight(p2);
				p3.y += _MaxWaveHeight * FindWaveHeight(p3);
				p4.y += _MaxWaveHeight * FindWaveHeight(p4);

				float3 op1 = p1 - pos, op2 = p2 - pos, op3 = p3 - pos, op4 = p4 - pos;

				float3 nor1 = cross(op1, op2), nor2 = cross(op2, op3), nor3 = cross(op3, op4), nor4 = cross(op4, op1);

				return lerp(lerp(nor1, nor2, 0.5), lerp(nor3, nor4, 0.5), 0.5);

				//return float3(0.0, 1.0, 0.0);
			}

			float StepPercent (float i)
			{
				float l = i / 14.0;
				l = pow(l, 1.0 / 0.45);
				return l;
			}
			
			[maxvertexcount(64)] //must specify limit with literal value... (MAY NEED TO LOOK INTO SHADER INSTANCING FOR MORE VERTICES; OR DECREASE SIZE OF V2F)
            void geom(triangle v2f input[3], inout TriangleStream<v2f> OutputStream)
            {
				float3 ab = input[1].vertex.xyz - input[0].vertex.xyz, ac = input[2].vertex.xyz - input[0].vertex.xyz,
				bc = input[2].vertex.xyz - input[1].vertex.xyz;

				float abL = length(ab), acL = length(ac), bcL = length(bc);

				float3 perp, diagA, diagB;				
				
				perp = input[2].vertex.xyz; //- float3(0.0,0.0,0.0)
				diagA = input[0].vertex.xyz;
				diagB = input[1].vertex.xyz;
				
				
				v2f generated = (v2f)0;		

				generated.vertex = UnityObjectToClipPos(float4(0.0, 0.0,  _MaxWaveHeight * FindWaveHeight(float3(0.0, 0.0, 0.0)), 1)); //add center
				generated.normal = FindNormal(float3(0.0, 0.0,  _MaxWaveHeight * FindWaveHeight(float3(0.0, 0.0, 0.0))));					
				generated.uv = float2(0.5, 0.5);//Sort out UVs later
				OutputStream.Append(generated);

				for(float i = 1.0; i < 15.0; i++) //add two vertices per loop
				{	
					float4 pos = float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1);										
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);					
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);

					pos = float4(diagA.x * StepPercent(i), diagA.y * StepPercent(i), diagA.z * StepPercent(i), 1);
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);
				}
								
				OutputStream.RestartStrip();
				
				generated.vertex = UnityObjectToClipPos(float4(0.0, 0.0, _MaxWaveHeight * FindWaveHeight(float3(0.0, 0.0, 0.0)), 1)); //add center
				generated.normal = FindNormal(float3(0.0, 0.0,  _MaxWaveHeight * FindWaveHeight(float3(0.0, 0.0, 0.0))));						
				generated.uv = float2(0.5, 0.5);//Sort out UVs later
				OutputStream.Append(generated);

				/*for(float i = 1.0; i < 15.0; i++) //add two vertices per loop (PASSING VERTICES IN THIS ORDER FLIPS THE TRIANGLE UPSIDE DOWN!!!)
				{	
					float4 pos = float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1);										
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);					
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);

					pos = float4(diagB.x * StepPercent(i), diagB.y * StepPercent(i), diagB.z * StepPercent(i), 1);
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);
				}*/

				for(float i = 1.0; i < 15.0; i++) //add two vertices per loop
				{	
					float4 pos = float4(diagB.x * StepPercent(i), diagB.y * StepPercent(i), diagB.z * StepPercent(i), 1);
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);

					pos = float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1);										
					pos.z += _MaxWaveHeight * FindWaveHeight(pos);					
					generated.normal = FindNormal(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					generated.vertex = UnityObjectToClipPos(pos);
					OutputStream.Append(generated);
				}
				
				/*
				v2f generated = (v2f)0;		

				generated.vertex = UnityObjectToClipPos(float4(0.0, 0.0, 0.0, 1)); //add center
				generated.normal = FindNormal(generated.vertex.xyz);					
				generated.uv = float2(0.5, 0.5);//Sort out UVs later
				OutputStream.Append(generated);
				
				for(float i = 1.0; i < 15.0; i++) //add two vertices per loop
				{	
					float4 pos = float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1);
					generated.vertex = UnityObjectToClipPos(pos);	
					generated.normal = -FindNormal(pos);
					//generated.vertex.xyz += generated.normal * _MaxWaveHeight * FindWaveHeight(pos);
					generated.vertex.y += _MaxWaveHeight * FindWaveHeight(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);

					pos = float4(diagA.x * StepPercent(i), diagA.y * StepPercent(i), diagA.z * StepPercent(i), 1);
					generated.vertex = UnityObjectToClipPos(pos);
					generated.normal = FindNormal(pos);
					//generated.vertex.xyz += generated.normal * _MaxWaveHeight * FindWaveHeight(pos);
					generated.vertex.y += _MaxWaveHeight * FindWaveHeight(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);
				}

				OutputStream.RestartStrip();
				
				generated.vertex = UnityObjectToClipPos(float4(0.0, 0.0, 0.0, 1)); //add center
				generated.normal = FindNormal(-generated.vertex.xyz);					
				generated.uv = float2(0.5, 0.5);//Sort out UVs later
				OutputStream.Append(generated);
				
				{	
					float4 pos = float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1);
					generated.vertex = UnityObjectToClipPos(pos);	
					generated.normal = -FindNormal(pos);
					//generated.vertex.xyz += generated.normal * _MaxWaveHeight * FindWaveHeight(pos);
					generated.vertex.y += _MaxWaveHeight * FindWaveHeight(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);

					pos = float4(diagB.x * StepPercent(i), diagB.y * StepPercent(i), diagB.z * StepPercent(i), 1);
					generated.vertex = UnityObjectToClipPos(pos);
					generated.normal = FindNormal(pos);
					//generated.vertex.xyz += generated.normal * _MaxWaveHeight * FindWaveHeight(pos);
					generated.vertex.y += _MaxWaveHeight * FindWaveHeight(pos);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);
				}
				*/
            }
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				//fixed4 col = tex2D(_MainTex, i.uv);
				//fixed4 col = fixed4(0.3,0.1,0.85,1.0);
				fixed4 col = fixed4(i.normal.x, i.normal.y, i.normal.z, 1.0);
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
