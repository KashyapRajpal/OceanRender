Shader "Example/Linear Fog" {

  Properties {
    _MainTex ("Base (RGB)", 2D) = "white" {}
    _BumpMap ("Bumpmap", 2D) = "bump" {}
    _RefractionMap ("Refraction Map", 2D) = "refraction" {}
    _ReflectionMap ("Reflection Map", 2D) = "reflection" {}
	_ReflectionEnabled ("Reflection Enabled", Range(0,1)) = 1
	_RefractionEnabled ("Refracction Enabled", Range(0,1)) = 1
	_TextureEnabled ("Texture Color Enabled", Range(0,1)) = 1
	_LightningEnabled ("Lightning Enabled", Range(0,1)) = 1
    _SpaceFreq ("Space Frequency", Range(-1,100)) = 1
    _TimeFreq ("Time Frequency", Range(0,1)) = 0.5
    _Amplitudes ("Amplitudes", Vector) = (0,0,0,0)
    _xAmbient ("Ambient Light Factor", Range(0,1)) = 0.2
    _xFresnelDistance ("Fresnel Distance", Range(0,100)) = 1
    _xDullFactor ("Dull Factor", Range(0,1)) = 0.5
    _LightDirection ("Light Direction", Vector) = (0,0,0,0)
    _UVDisplacementVelocity ("UV Displacement Velocity", Vector) = (-0.04, 0.002,0,0)
	_ReflectionDistortion ("Reflection Distortion", Range(0,1)) = 0.5
	_RefractionDistortion ("Refractive Distortion", Range(0,1)) = 0.5
	_RefractionColor ("Refraction color", COLOR)  = ( .34, .85, .92, 1)
	_SpecularPower ("Specular Power Coefficent", Range(2,64)) = 16
  }
  SubShader {
    Tags { "RenderType"="Opaque" }
    LOD 200
  
    CGPROGRAM
    #pragma glsl
    #pragma target 3.0
    #pragma debug
    #pragma surface surf Lambert finalcolor:WaterPS vertex:WaterVS
	#include "UnityCG.cginc"

    sampler2D _MainTex: register(s0);
    sampler2D _BumpMap: register(s2);
    sampler2D _RefractionMap;
    sampler2D _ReflectionMap: register(s3); 
    sampler2D _GrabTexture : register(s4);
	
    struct Input {
      float2 uv_MainTex;
      float3 normal;
      float3 Position3D;
      float phase;
      float4 RefractionMapSamplingPos;
      float3 viewDir;
	  float4 screenPos;
      float3 worldRefl;
      INTERNAL_DATA
    }; 
      
    float _xDullFactor;
    float _xFresnelDistance; 
    float _xAmbient;
    float _SpaceFreq;
    float _TimeFreq;
    float4 _Amplitudes;
	float _rAmplitudes = 1;
	float _rSpaceFreq = 1; 
	float3 _LightDirection;
	float2 _UVDisplacementVelocity;
	float _ReflectionDistortion;
	float _RefractionDistortion;
	float4 _RefractionColor;
	float _SpecularPower;
	int _ReflectionEnabled;
	int _RefractionEnabled;
	int _TextureEnabled;
	int _LightningEnabled;

    void WaterVS (inout appdata_full v, out Input data) {
		UNITY_INITIALIZE_OUTPUT(Input,data);
      	float4 cCos,cSin;
		float4 vertexPosition = v.vertex;
		
		//Calculates correction phase/height based on vertex position, space frequency and time
		float4 correctionPhase = (vertexPosition.x + vertexPosition.y) * _SpaceFreq + _Time * _TimeFreq;
		sincos(correctionPhase,cSin,cCos); 
		float correctionHeight = dot(cSin, _Amplitudes/2); 

		//radial waves 
		float distance = length(float2(vertexPosition.x, vertexPosition.y)); 
		float Phase = distance * -_rSpaceFreq + _Time * 2 * -_TimeFreq; 
 
		//Calcule waveheight according to amplitudes and correction phase
		float Cos,Sin; 
		int power = 7; 
		sincos(Phase,Sin,Cos); 
		float temp2 = 1; 
		if (Cos * Sin < 0) 
			temp2 = 2;
		float WaveHeight = clamp(pow(Sin,power) * _rAmplitudes * temp2 - (_rAmplitudes*(temp2-1)), 0, _rAmplitudes) + correctionHeight; 
		
		//adds the calculated wave height to the current vertex position
		float4 newPosition = vertexPosition + float4(0,WaveHeight,0,0);
		v.vertex.xyz = newPosition; 
		
		//moves uv coordinates to simulate water movement. U and V are tiled by a factor of 10. Also velocity is considered to move UVs
		v.texcoord.xy = float2(v.texcoord.x/10, v.texcoord.y/10) + _UVDisplacementVelocity *_Time;
		 	  		  
		//assign the new normal for the vertex. We use X and Y Axis to calculate a normalized Z axis			  
		v.normal = normalize(cross( float3(0,1,0), float3(1,0,0))); 

		data.phase = Sin*Sin/2+0.5;
		
		//calculates projected vertex position in Homogeneous Space using the Model View Projection Matrix
		float4 projectedPosition = mul(UNITY_MATRIX_MVP, newPosition);
		
		//output variables
		data.RefractionMapSamplingPos = ComputeScreenPos(projectedPosition); //Projected Screen Space position
		data.uv_MainTex = v.texcoord;
		data.normal = v.normal;
		data.Position3D = newPosition; 
    }
    
    void WaterPS (Input IN, SurfaceOutput o, inout fixed4 color) {
         
		float3 finalColor =0;
		 
		//retrieve normal from the Bump/Normal map using the displaced UVs
		float3 normal = tex2D(_BumpMap,IN.uv_MainTex.xy); 
		
		//calculate new normal bu adding Bump normal and normal calculated every vertex
		float3 newNormal = normalize(normalize(IN.normal) + normal); 

		//////////// ADDS REFLECTION
		
		float4 uv1 = IN.RefractionMapSamplingPos; 
		uv1.xy += newNormal * _ReflectionDistortion;  					//add the new normal multiplied by a distortion parameter
		uv1.y +=4;														//add some perturbation on Y axis
		float4 uvfinal = UNITY_PROJ_COORD(uv1);  						//calculates a texture coordinate suitable for projected texture reads
		uvfinal.y = uvfinal.y *-1;										//flips Y Axis
		float4 reflectiveColor = tex2Dproj( _ReflectionMap, uvfinal );  //performs a texture lookup with projection in the Reflection Map
	
		//////////// ADDS REFRACTION
		
		float4 uv2 = IN.RefractionMapSamplingPos; 
		uv2.xy -= newNormal * _RefractionDistortion;					//substract the new normal multiplied by a distortion parameter
		float4 uvfinalR = UNITY_PROJ_COORD(uv2); 						//calculates a texture coordinate suitable for projected texture reads
		float4 refractiveColor = tex2Dproj( _RefractionMap, uvfinalR); 	//performs a texture lookup with projection in the Refraction Map
		refractiveColor *= refractiveColor;								//multiplies calculated value by the refraction color

		
		//////////// CALCULATE FRESNEL TERM
		
		//calculate fresnel according to the position of camera and every vertex
		float fresnelTerm = saturate(length(_WorldSpaceCameraPos.xy - IN.Position3D.xy)/ _xFresnelDistance);  
		
		//add refraction/reflection color according to fresnel term
		if((_ReflectionEnabled ==1) && (_RefractionEnabled))
		{
			finalColor = reflectiveColor * fresnelTerm + refractiveColor * (1-fresnelTerm); 
		}
		else
		{
			if(_ReflectionEnabled == 1)
				finalColor = reflectiveColor;	
			if(_RefractionEnabled == 1)
				finalColor = refractiveColor;
		}

		//////////// ADD DULL COLOR
		
		float phase = (_rAmplitudes-clamp(IN.phase,0,_rAmplitudes)); 						//clamps the phase between 0 and the amplitud values
		float3 dullColor = float3(0.1,0.25,0.5);											//predefined dull color
		_xDullFactor = saturate(_xDullFactor * (1+IN.phase*IN.phase*IN.phase*IN.phase)); 	//calculate dull factor according to the phase.
		finalColor = finalColor *(1 - _xDullFactor) + dullColor *_xDullFactor;				//add dull color according to dill factor.
		
		
		//////////// ADD TEXTURE COLOR
		
		float3 textureColor = tex2D (_MainTex, IN.uv_MainTex);			//lookup water texture using calculated UV for every pixel
		
		if(_TextureEnabled == 1)
			finalColor = (finalColor * 0.90) + (textureColor * 0.10);		//combines color with texture color. 10% texture color
		
		
		//////////// ADD LIGHTNING COLOR
		
		//normalizes sun light direction parameter
		float3 LightDirection = normalize(_LightDirection); 								
		
		//calculates lightning factor according to the calculated normal and the sun light direction. 
		//Also, ambient light factor is considered as parameter.
		float lightingFactor = saturate(saturate(dot(newNormal, LightDirection)) + _xAmbient); 
		
		//calculates camera vector according to camera position and vertex position
		float3 eyeVector = normalize(_WorldSpaceCameraPos.xyz - IN.viewDir.xyz); 
		float3 halfVector = normalize(LightDirection + eyeVector); 

		//calculates specular term based on camera vector and reflection
		float specTerm = pow(dot(halfVector,normalize(IN.normal+normal/1.5)),_SpecularPower); 
		//multiplies specular term by the specular color
		float3 specColor = float3(0.98,0.97,0.7) * specTerm; 

		//adds lightning to the calculated color 
		//multiplies calculated color with calculated specular color
		if(_LightningEnabled == 1)
			finalColor = finalColor*lightingFactor+specColor;
		
		color =  float4(finalColor, 1.0f); 
 
    }

    void surf (Input IN, inout SurfaceOutput o) 
	{
	
    }
    ENDCG
  } 
  FallBack "Diffuse"
}