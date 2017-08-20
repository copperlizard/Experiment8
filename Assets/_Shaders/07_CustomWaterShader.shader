Shader "Custom/07_CustomWaterShader" 
{
	Properties 
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_BumpMap ("Bump Map", 2D) = "bump" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_WaveAmplitude ("WaveAmplitude", float) = 0.25
		_NormalScanTriSideLength ("NormalScanTriSideLength", float) = 0.1
	}
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		Blend SrcAlpha OneMinusSrcAlpha
		LOD 200
		
		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types, plus vertex shader
		#pragma surface surf Standard fullforwardshadows vertex:vert

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		struct Input 
		{
			float2 uv_MainTex;
		};

		sampler2D _MainTex;
		sampler2D _BumpMap;
		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		float _WaveAmplitude;
		float _NormalScanTriSideLength;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		//UNITY_INSTANCING_CBUFFER_START(Props)
			// put more per-instance properties here
		//UNITY_INSTANCING_CBUFFER_END

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
		////End Helper Functions

		void vert (inout appdata_full v) 
		{
			v.vertex.y += _WaveAmplitude * PerlinNoise(mul(unity_ObjectToWorld, v.vertex.xz * 0.25 + _Time.xx));
			//v.vertex.y += _WaveAmplitude;
			v.normal = FindWaterNormal(v.vertex.xyz);
		}

		void surf (Input IN, inout SurfaceOutputStandard o) 
		{
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex - _Time.xx * 0.5) * _Color;
			o.Albedo = c.rgb;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
			o.Normal = UnpackNormal (tex2D (_BumpMap, IN.uv_MainTex - _Time.xx * 0.5));
		}
		ENDCG
	}
	FallBack "Diffuse"
}
