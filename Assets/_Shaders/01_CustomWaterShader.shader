Shader "Unlit/01_CustomWaterShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_TriangulationSteps ("TriangulationSteps", Int) = 3
	}
	SubShader
	{
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
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				//float4 worldPosition : TEXCOORD1; //using vertex as world pos...
				float3 normal : NORMAL;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			int _TriangulationSteps;

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

			float StepPercent (float i)
			{
				float l = i / 14.0;
				l = pow(l, 1.0 / 0.1);
				return l;
			}

			float3 FindNormal (float3 pos)
			{
				return float3(0.0, 1.0, 0.0);
			}

			float FindWaveHeight (float3 pos)
			{
				return 0.0;
			}
			
			[maxvertexcount(64)] //must specify limit with literal value... (MAY NEED TO LOOK INTO SHADER INSTANCING FOR MORE VERTICES; OR DECREASE SIZE OF V2F)
            void geom(triangle v2f input[3], inout TriangleStream<v2f> OutputStream)
            {
			/*
				The Plan:				
				Take input tri and convert to two tristrips...
								
				Goals:
				Mesh complexity should decrease as distance from center increases.

				Axioms:
				Input will always be a quad (0.0,0.0 (LS) is center of mesh)...
				
				Steps:
				Check dist between 3 points (because quad: 1 dist will be greater than other 2)
				
				Use greatest dist pair to build "diag," and the remaining point and center point to build "perp"

				start with center point, then step T along perp and diag where T is determined forumlaically... then generate the other tri strip...

				Use four adjacent points to determine normal at each vertex
			*/

				float3 ab = input[1].vertex.xyz - input[0].vertex.xyz, ac = input[2].vertex.xyz - input[0].vertex.xyz,
				bc = input[2].vertex.xyz - input[1].vertex.xyz;

				float abL = length(ab), acL = length(ac), bcL = length(bc);

				float3 perp, diagA, diagB;				
				if (abL >= acL && abL >= bcL) //ab = diag, Oc = perp  (I think is should always be this one, but not willing to assume (test later)...)
				{
					perp = input[2].vertex.xyz; //- float3(0.0,0.0,0.0)
					diagA = input[0].vertex.xyz;
					diagB = input[1].vertex.xyz;
				}
				else if (acL >= abL && acL >= bcL) //ac = diag, Ob = perp
				{
					perp = input[1].vertex.xyz; //- float3(0.0,0.0,0.0)
					diagA = input[0].vertex.xyz;
					diagB = input[2].vertex.xyz;
				}
				else if (bcL >= acL && bcL >= abL) //bc = diag, Oa = perp
				{
					perp = input[0].vertex.xyz; //- float3(0.0,0.0,0.0)
					diagA = input[1].vertex.xyz;
					diagB = input[2].vertex.xyz;
				}

				v2f generated = (v2f)0;		

				generated.vertex = UnityObjectToClipPos(float4(0.0, 0.0, 0.0, 1)); //add center
				generated.normal = FindNormal(generated.vertex.xyz);					
				generated.uv = float2(0.5, 0.5);//Sort out UVs later
				OutputStream.Append(generated);

				//NEED TO FIGURE OUT NORMALS FOR LIGHTING!!! THEN ADD LIGHTING!!! THEN ADD BUMP MAPPING(light stuff)!!!

				for(float i = 1.0; i < 15.0; i++) //add two vertices per loop
				{	
					generated.vertex = UnityObjectToClipPos(float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1));					
					generated.normal = FindNormal(generated.vertex.xyz);
					generated.vertex.xyz += generated.normal * 0.05 * sin(generated.vertex.x * generated.vertex.z * 30.0);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);

					generated.vertex = UnityObjectToClipPos(float4(diagA.x * StepPercent(i), diagA.y * StepPercent(i), diagA.z * StepPercent(i), 1));
					generated.normal = FindNormal(generated.vertex.xyz);
					generated.vertex.xyz += generated.normal * 0.05 * sin(generated.vertex.x * generated.vertex.z * 30.0);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);
				}
								
				OutputStream.RestartStrip();
				
				for(float i = 1.0; i < 15.0; i++) //add two vertices per loop
				{	
					generated.vertex = UnityObjectToClipPos(float4(perp.x * StepPercent(i), perp.y * StepPercent(i), perp.z * StepPercent(i), 1));	
					generated.normal = FindNormal(generated.vertex.xyz);
					generated.vertex.xyz += generated.normal * 0.05 * sin(generated.vertex.x * generated.vertex.z * 30.0);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);

					generated.vertex = UnityObjectToClipPos(float4(diagB.x * StepPercent(i), diagB.y * StepPercent(i), diagB.z * StepPercent(i), 1));
					generated.normal = FindNormal(generated.vertex.xyz);
					generated.vertex.xyz += generated.normal * 0.05 * sin(generated.vertex.x * generated.vertex.z * 30.0);
					generated.uv = float2(0.5, 0.5);//Sort out UVs later
					OutputStream.Append(generated);
				}
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
