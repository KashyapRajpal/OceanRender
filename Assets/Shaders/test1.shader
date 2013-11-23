Shader "Example/Linear Fog" {

  Properties {
    _MainTex ("Base (RGB)", 2D) = "white" {}
    _BumpMap ("Bumpmap", 2D) = "bump" {}
    _RefractionMap ("Refraction Map", 2D) = "refraction" {}
    _ReflectionMap ("Reflection Map", 2D) = "reflection" {}
    _WaveDirX ("Wave Direction X", Range(-1,1)) = 1
    _WaveDirY ("Wave Direction Y", Range(-1,1)) = 1
    _SpaceFreq ("Space Frequency", Range(-1,100)) = 1
    _TimeFreq ("Time Frequency", Range(0,1)) = 0.5
    _Amplitudes ("Amplitudes", Vector) = (0,0,0,0)
    _rAmplitudes ("RAmplitudes", Range(-1,1)) = 0.5
    _xIslandScale ("X Island Scale", Range(-1,1)) = 1
    _xWaterSlope ("X Water Slope", Range(-1,100)) = 1
    _xWaterLevel ("X Water Level", Range(-1,1)) = 1
    _rSpaceFreq ("RSpace Frequency", Range(-1,100)) = 1
    _xAmbient ("Ambient", Range(0,1)) = 0.2
    _xFresnelDistance ("Fresnel Distance", Range(0,1000)) = 1
    _xDullFactor ("Dull Factor", Range(0,1)) = 0.5
    _LightDirection ("Light Direction", Vector) = (0,0,0,0)
    _UVDisplacementVelocity ("UV Displacement Velocity", Vector) = (-0.04, 0.002,0,0)
  }
  SubShader {
    Tags { "RenderType"="Opaque" }
    LOD 200
 
    CGPROGRAM
    #pragma target 3.0
    #pragma surface surf Lambert finalcolor:WaterPS vertex:WaterVS
	#include "UnityCG.cginc"

    sampler2D _MainTex;
    sampler2D _BumpMap;
    sampler2D _RefractionMap;
    sampler2D _ReflectionMap;
    
    struct Input {
      float2 uv_MainTex;
      float3 normal;
      float phase;
      float4 RefractionMapSamplingPos;
      float3 Position3D;
      float3 worldRefl;
      INTERNAL_DATA
    }; 
      
    float _xDullFactor;
    float _xFresnelDistance; 
    float _xAmbient;
	float _WaveDirX; 
    float _WaveDirY; 
    float _SpaceFreq;
    float _TimeFreq;
    float4 _Amplitudes;
	float _rAmplitudes = 0;
	float _xIslandScale = 0;
	float _xWaterSlope = 0;
	float _xWaterLevel = 0;
	float _rSpaceFreq = 0; 
	float3 _LightDirection;
	float2 _UVDisplacementVelocity;

    void WaterVS (inout appdata_full v, out Input data) {
		UNITY_INITIALIZE_OUTPUT(Input,data);
      
		float4 pPos = v.vertex;
		float4 correctionPhase = (_WaveDirX * pPos.x + _WaveDirY * pPos.y) * _SpaceFreq + 10 * _Time * _TimeFreq;

		float4 cCos,cSin; 
		sincos(correctionPhase,cSin,cCos); 
		float correctionHeight = dot(cSin, _Amplitudes/2); 

		//radial waves 
		float distance = length(float2(pPos.x - 64 * _xIslandScale, pPos.y - 64 * _xIslandScale)); 
		float Phase = distance * -_rSpaceFreq + _Time * 2 * -_TimeFreq; 
 

		//Calculating waveheight 
		float Cos,Sin; 
		int power = 7; 
		sincos(Phase,Sin,Cos); 
		float temp2 = 1; 
		if (Cos * Sin < 0) 
			temp2 = 2;
			 	 
		float WaveHeight = clamp(pow(Sin,power) * _rAmplitudes * temp2 - (_rAmplitudes*(temp2-1)), 0, _rAmplitudes) + 
			(_xIslandScale * 128 - distance)/_xWaterSlope/2 + _xWaterLevel + correctionHeight; 

		//moves the water in the 
		float4 newPos = pPos + float4(0,WaveHeight,0,0);
		v.vertex.xyz = newPos; 
		
		//moves uv coordinates to simulate water movement
		float4 originalUV = (v.texcoord);
		v.texcoord.xy = float2(v.texcoord.x/10, v.texcoord.y/10) + _UVDisplacementVelocity *_Time;
		 	  		  
		float3 normal_before = v.normal; 	  		  
		v.normal = normalize(cross( float3(0,1,0), float3(1,0,0))); 

		float temp = 0; 
 		if (Sin > 0) 
 			temp = power * Cos * pow ( Sin, power-1 ); 

		data.phase = Sin*Sin/2+0.5;
		data.RefractionMapSamplingPos = originalUV;
		data.uv_MainTex = v.texcoord;
		data.normal = v.normal;
		data.Position3D = pPos; 

    }
    
     
     
    void WaterPS (Input IN, SurfaceOutput o, inout fixed4 color) {
          
		float3 normal = tex2D(_BumpMap,IN.RefractionMapSamplingPos.xy)* 2.0 - 1.0; 
		float3 newNormal = normalize(normalize(IN.normal) + normal); 

		//ADDS REFLECTION AND REFRACTION
		float2 RefractionSampleTexCoords; 
		RefractionSampleTexCoords.x = IN.RefractionMapSamplingPos.x;///IN.RefractionMapSamplingPos.w/2.0f + 0.5f; 
		RefractionSampleTexCoords.y = -IN.RefractionMapSamplingPos.y;///IN.RefractionMapSamplingPos.w/2.0f + 0.5f; 

		float4 refractiveColor = tex2D(_RefractionMap, RefractionSampleTexCoords-newNormal*0.2);
		float4 reflectiveColor = tex2D(_ReflectionMap, RefractionSampleTexCoords+newNormal*0.2);
		
		float phase = (_rAmplitudes-clamp(IN.phase,0,_rAmplitudes)); 
		float fresnelTerm = saturate(length(_WorldSpaceCameraPos.xy - IN.Position3D.xy)/ _xFresnelDistance)+0.0000001; 
		//fresnelTerm = 0.5;
		float3 finalColor = reflectiveColor * fresnelTerm + refractiveColor * (1-fresnelTerm);

		// ADDING DULL COLOR
		float3 dullColor = float3(0.1,0.25,0.5);
		float dullFactor = _xDullFactor;
		dullFactor = saturate(dullFactor * (1+IN.phase*IN.phase*IN.phase*IN.phase));

		finalColor = finalColor *(1 - dullFactor) + dullColor *dullFactor;
		
		
		// ADDS TEXTURE COLOR
		float3 textureColor = tex2D (_MainTex, IN.uv_MainTex);
		finalColor = (finalColor * 0.75) + (textureColor * 0.25);
		
		
		//lighting factor computation 
		float3 LightDirection = normalize(_LightDirection); 
		float lightingFactor = saturate(saturate(dot(normal, LightDirection)) + _xAmbient); 
		
		float3 lightDir = normalize(float3(10.84,-12.99,3)); 
		float3 eyeVector = normalize(_WorldSpaceCameraPos.xyz - IN.Position3D.xyz); 
		float3 halfVector = normalize(lightDir + eyeVector); 

		float temp = 0; 
		temp = pow(dot(halfVector,normalize(IN.normal+normal/1.5)),16); 
		float3 specColor = float3(0.98,0.97,0.7)*temp; 

		finalColor = finalColor*lightingFactor+specColor;

		color =  float4(finalColor, 1.0f); 
	 

    }

    void surf (Input IN, inout SurfaceOutput o) {
      //half4 c = tex2D (_MainTex, IN.uv_MainTex);
      //o.Albedo = c.rgb;
      //o.Alpha = c.a;
      
      //o.Normal = IN.normal;
      //o.Albedo = tex2D (_MainTex, IN.uv_MainTex).rgb * 0.5;
      //o.Emission = texCUBE (_CubeMap, WorldReflectionVector(IN, o.Normal)).rgb;
    }
    ENDCG
  } 
  FallBack "Diffuse"
}