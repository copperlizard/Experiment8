// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/01_ShieldShader"
{
	Properties
	{
		_Color("Color", Color) = (0,0,0,0)
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Blend One One
		ZWrite Off
		Cull Off

		Tags
		{
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
		}


		Pass
		{
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			
			// make fog work
			//#pragma multi_compile_fog
			
			#include "UnityCG.cginc"			

			struct appdata
			{
				float4 vertex : POSITION;
				//float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				//float2 uv : TEXCOORD0;
				float2 screenuv : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				float3 objectPos : TEXCOORD3;
				float4 vertex : SV_POSITION;
				float depth : DEPTH;
				float3 normal : NORMAL;
			};

			/*
			float random(in float2 st)
			{
				return frac(sin(dot(st.xy, float2(12.9898, 78.233)))	* 43758.5453123);
			}

			// 2D Noise based on Morgan McGuire @morgan3d
			// https://www.shadertoy.com/view/4dS3Wd
			float noise(in float2 st)
			{
				float2 i = floor(st);
				float2 f = frac(st);

				// Four corners in 2D of a tile
				float a = random(i);
				float b = random(i + float2(1.0, 0.0));
				float c = random(i + float2(0.0, 1.0));
				float d = random(i + float2(1.0, 1.0));

				// Smooth Interpolation

				// Cubic Hermine Curve.  Same as SmoothStep()
				float2 u = f * f * (3.0 - 2.0 * f);
				// u = smoothstep(0.,1.,f);

				// Mix 4 coorners porcentages
				return lerp(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
			}
			*/

			float mod289(float x) 
			{ 
				return x - floor(x * (1.0 / 289.0)) * 289.0;
			}

			float4 mod289(float4 x)
			{ 
				return x - floor(x * (1.0 / 289.0)) * 289.0;
			}

			float4 perm(float4 x) 
			{ 
				return mod289(((x * 34.0) + 1.0) * x);
			}

			float noise(float3 p) 
			{
				float3 a = floor(p);
				float3 d = p - a;
				d = d * d * (3.0 - 2.0 * d);

				float4 b = a.xxyy + float4(0.0, 1.0, 0.0, 1.0);
				float4 k1 = perm(b.xyxy);
				float4 k2 = perm(k1.xyxy + b.zzww);

				float4 c = k2 + a.zzzz;
				float4 k3 = perm(c);
				float4 k4 = perm(c + 1.0);

				float4 o1 = frac(k3 * (1.0 / 41.0));
				float4 o2 = frac(k4 * (1.0 / 41.0));

				float4 o3 = o2 * d.z + o1 * (1.0 - d.z);
				float2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

				return o4.y * d.y + o4.x * (1.0 - d.y);
			}

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata_base v) 
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				o.screenuv = ((o.vertex.xy / o.vertex.w) + 1) / 2;
				o.screenuv.y = 1 - o.screenuv.y;
				o.depth = -mul(UNITY_MATRIX_MV, v.vertex).z *_ProjectionParams.w;

				o.objectPos = v.vertex.xyz;
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.viewDir = normalize(UnityWorldSpaceViewDir(mul(unity_ObjectToWorld, v.vertex)));

				o.vertex += UnityObjectToClipPos(v.normal) * noise(o.normal * 1.5 + _Time.xyz) * 0.2;

				return o;
			}

			sampler2D _CameraDepthNormalsTexture;
			fixed4 _Color;

			fixed4 frag(v2f i) : SV_Target
			{
				float screenDepth = DecodeFloatRG(tex2D(_CameraDepthNormalsTexture, i.screenuv).zw);
				float diff = screenDepth - i.depth;
				float intersect = 0;

				if (diff > 0)
				{
					intersect = 1 - smoothstep(0, _ProjectionParams.w * 0.5, diff);
				}

				float rim = 1 - abs(dot(i.normal, normalize(i.viewDir))) * 2;
				//float northPole = (i.objectPos.y - 0.45) * 20;
				//float glow = max(max(intersect, rim), northPole);


				float wave = noise(i.normal + _Time.xyz * 0.5);
				float wig = 0.05 * cos(_Time.x);
				wave = smoothstep(0.47 + wig, 0.5 + wig, wave) - smoothstep(0.5 + wig, 0.53 + wig, wave);

				float glow = max(max(intersect, rim), wave);


				fixed4 glowColor = fixed4(lerp(_Color.rgb, fixed3(1, 1, 1), pow(glow, 4)), 1);

				fixed4 col = _Color * _Color.a + glowColor * glow;
				return col;
			}
			ENDCG
		}
	}
}
