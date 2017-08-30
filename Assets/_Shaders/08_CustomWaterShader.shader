// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/08_CustomWaterShader"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex ("Texture", 2D) = "white" {}
		_OcclusionMap("Occlusion", 2D) = "white" {}
		_BumpMap ("Bump Map", 2D) = "bump" {}
		_WaveAmplitude ("WaveAmplitude", float) = 0.25
		_NormalScanTriSideLength ("NormalScanTriSideLength", float) = 0.1	
		
		//_realTime  ("realTime", float) = 0.0
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One
		ZWrite Off //causes skybox to eat water
		Cull off
		//LOD 100
		
		Pass
		{
			Tags { "LightMode"="ForwardBase" } //surface darker without...

			CGPROGRAM

			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "UnityLightingCommon.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float4 tangent : TANGENT;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 pos : TEXCOORD1;
				float3 normal : TEXCOORD2;

				//transforms from tangent to world space
                half3 tspace0 : TEXCOORD3; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD4; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD5; // tangent.z, bitangent.z, normal.z

				float2 screenuv : TEXCOORD6;

				fixed3 shade : COLOR0;
				fixed3 ambient : COLOR1;

				float depth : DEPTH;

				UNITY_FOG_COORDS(7)
			};

			sampler2D _CameraDepthNormalsTexture; //built in

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			sampler2D _OcclusionMap;
			float4 _OcclusionMap_ST;
			float _WaveAmplitude;
			float _NormalScanTriSideLength;

			float _realTime;

			////Helper Functions
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

			float2 fade(float2 t) 
			{
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
				//p1.y += _WaveAmplitude * PerlinNoise(p1.xz * 0.25 + _Time.xx); 
				//p2.y += _WaveAmplitude * PerlinNoise(p2.xz * 0.25 + _Time.xx);
				//p3.y += _WaveAmplitude * PerlinNoise(p3.xz * 0.25 + _Time.xx);
				p1.y += _WaveAmplitude * PerlinNoise(p1.xz * 0.25 + float2(_realTime, _realTime)); 
				p2.y += _WaveAmplitude * PerlinNoise(p2.xz * 0.25 + float2(_realTime, _realTime));
				p3.y += _WaveAmplitude * PerlinNoise(p3.xz * 0.25 + float2(_realTime, _realTime));


				float3 p1p2 = p2 - p1, p1p3 = p3 - p1;

				return normalize(cross(normalize(p1p2), normalize(p1p3)));
			}
			////End Helper Functions

			////Shaders
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = v.vertex;
				//o.pos.y += _WaveAmplitude * PerlinNoise(mul(unity_ObjectToWorld, o.pos).xz * 0.25 + _Time.xx * 5.0);
				o.pos.y += _WaveAmplitude * PerlinNoise(mul(unity_ObjectToWorld, o.pos).xz * 0.25 + float2(_realTime, _realTime));
				o.normal = FindWaterNormal(o.pos);
				o.vertex = UnityObjectToClipPos(o.pos);
				o.screenuv = ((o.vertex.xy / o.vertex.w) + 1) / 2;
				o.screenuv.y = 1 - o.screenuv.y;
				o.pos = mul(unity_ObjectToWorld, o.pos);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);				
				o.depth = -UnityObjectToViewPos(v.vertex).z * _ProjectionParams.w;
				//o.depth = -mul(UNITY_MATRIX_MV, o.pos).z * _ProjectionParams.w;

				half3 wNormal = UnityObjectToWorldNormal(o.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

				half nl = max(0, dot(wNormal, _WorldSpaceLightPos0.xyz));
                o.shade = nl * _LightColor0;

				o.shade += ShadeSH9(half4(wNormal, 1));
				o.ambient = ShadeSH9(half4(wNormal, 1));
				
				UNITY_TRANSFER_FOG(o, o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float screenDepth = DecodeFloatRG(tex2D(_CameraDepthNormalsTexture, i.screenuv).zw);
				float diff = screenDepth - i.depth;
				float intersect = 0;
				if (diff > 0)
				{
					intersect = 1 - smoothstep(0, _ProjectionParams.w * 0.5, diff);
				}

				//fixed2 uv1 = (i.uv - _Time.xx * 0.3);
				//fixed2 uv2 = (i.uv - float2(_Time.x * 0.5, _Time.x + 0.2) * 0.45);
				fixed2 uv1 = (i.uv - float2(_realTime, _realTime) * 0.3);
				fixed2 uv2 = (i.uv - float2(_realTime * 0.5, _realTime + 0.2) * 0.45);

				// texture normals
				float3 bumpNorm1 = UnpackNormal(tex2D(_BumpMap, uv1));
				float3 worldBumpNorm1;
                worldBumpNorm1.x = dot(i.tspace0, bumpNorm1);
                worldBumpNorm1.y = dot(i.tspace1, bumpNorm1);
                worldBumpNorm1.z = dot(i.tspace2, bumpNorm1);

				float3 bumpNorm2 = UnpackNormal(tex2D(_BumpMap, uv2));
				float3 worldBumpNorm2;
                worldBumpNorm2.x = dot(i.tspace0, bumpNorm2);
                worldBumpNorm2.y = dot(i.tspace1, bumpNorm2);
                worldBumpNorm2.z = dot(i.tspace2, bumpNorm2);

				// find surface normal
				float3 surfNorm = FindWaterNormal(i.pos);

				// get sky color
				half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.pos));
                
				half3 worldRefl1 = reflect(-worldViewDir, worldBumpNorm1);
                half4 skyData1 = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl1);
				half3 skyColor1 = DecodeHDR (skyData1, unity_SpecCube0_HDR);

				half3 worldRefl2 = reflect(-worldViewDir, worldBumpNorm2);
                half4 skyData2 = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl2);                
				half3 skyColor2 = DecodeHDR (skyData2, unity_SpecCube0_HDR);

				//float m = 0.5 + 0.25 * ((cos(_Time.x * 2.0) + 1.0) / 2.0);
				float m = 0.5;

				// blend bump and surface normals     //(varies over time and surface to simulate wind...) 0.15 * PerlinNoise(i.pos.xz * 0.5 + _Time.xx * 10.0)
				float3 blendNorm = lerp(lerp(bumpNorm1, bumpNorm2, m), surfNorm, 0.5); 

				// sample and tint the texture
				fixed4 col = lerp(tex2D(_MainTex, uv1), tex2D(_MainTex, uv2), m) * _Color;
				
				// lighting (per vertex)
				col.rgb *= i.shade + i.ambient;

				// reflect skybox
				col.rgb += lerp(skyColor1, skyColor2, m); //might want to do this before shade...

				// occlusion shadows
				col.rgb *= lerp(tex2D(_OcclusionMap, uv1).r, tex2D(_OcclusionMap, uv2).r, m); //might want to do this before shade...		
				
				col.rgb += intersect * ((PerlinNoise(i.pos.xz * 10.0 + _Time.xx) + 1.0) / 2.0); //ripple zone...
				
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
			////End Shaders
		}
	}
}