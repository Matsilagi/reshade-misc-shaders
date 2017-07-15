// The final step of the CRT simulation process is to take the output of composite.fx (a 256x224 texture map)
// and draw it to a 3D mesh of a curved CRT screen. This is the step where we apply effects "outside the screen,"
// including the shadow mask, lighting, and so on.

#include "ReShade.fxh"

uniform float CRTMask_Scale <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 4096.0;
	ui_label = "CRT Mask Scale [SuperCRT]";
> = 1.0;

uniform float UVScalarX <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_WIDTH;
	ui_label = "UV Scalar X [SuperCRT]";
> = 1.0;

uniform float UVScalarY <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_HEIGHT;
	ui_label = "UV Scalar Y [SuperCRT]";
> = 1.0;

uniform float UVOffsetX <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = BUFFER_WIDTH;
	ui_label = "UV Offset X [SuperCRT]";
> = 0.0;

uniform float UVOffsetY <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = BUFFER_HEIGHT;
	ui_label = "UV Offset Y [SuperCRT]";
> = 0.0;

uniform float Tuning_Overscan <
	ui_type = "drag";
	ui_min = 0.8;
	ui_max = 2.0;
	ui_label = "Overscan [SuperCRT]";
> = 1.0;

uniform float Tuning_Dimming <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Edge Dimming [SuperCRT]";
> = 0.37;

uniform float Tuning_Satur <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 4.0;
	ui_label = "Saturation [SuperCRT]";
> = 1.0;

uniform float Tuning_ReflScalar < 
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Edge Reflection [SuperCRT]";
> = 1.0;

uniform float Tuning_Barrel <
	ui_type = "drag";
	ui_min = -0.5;
	ui_max = 2.0;
	ui_label = "Barrel Distortion [SuperCRT]";
> = -0.12;

uniform float Tuning_Scanline_Brightness <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_label = "Scanline Brightness [SuperCRT]";
> = 0.45;

uniform float Tuning_Scanline_Opacity <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Scanline Intensity [SuperCRT]";
> = 1.0;

uniform float Tuning_Diff_Brightness <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_label = "Diffuse Light [SuperCRT]";
> = 0.0;

uniform float Tuning_Spec_Brightness <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 5.0;
	ui_label = "Specular Light [SuperCRT]";
> = 0.0;

uniform float Tuning_Spec_Power <
	ui_type = "drag";
	ui_min = 5.0;
	ui_max = 200.0;
	ui_label = "Specular Power [SuperCRT]";
> = 0.0;

uniform float Tuning_Fres_Brightness <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_label = "Rim Light [Super CRT]";
> = 0.0;

uniform float Tuning_LightPosX <
	ui_type = "drag";
	ui_min = -20.0;
	ui_max = 20.0;
	ui_label = "Light Position X [SuperCRT]";
> = 5.0;

uniform float Tuning_LightPosY <
	ui_type = "drag";
	ui_min = -20.0;
	ui_max = 20.0;
	ui_label = "Light Position Y [SuperCRT]";
> = -10.0;

uniform float Tuning_LightPosZ <
	ui_type = "drag";
	ui_min = -20.0;
	ui_max = 20.0;
	ui_label = "Light Position Z [SuperCRT]";
> = 1.0;

#define Tuning_LightPos float3(Tuning_LightPosX,Tuning_LightPosY,Tuning_LightPosZ);
#define UVScalar float2(UVScalarX,UVScalarY)
#define UVOffset float2(UVOffsetX,UVOffsetY)

texture scanlinesMap <source="crtsim_scanlines.png";> { Width=512; Height=256;};

sampler2D compFrameSampler
{
	Texture = ReShade::BackBufferTex;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = BORDER;
	AddressV = BORDER;
};

sampler2D scanlinesSampler
{
	Texture = scanlinesMap ;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = WRAP;
	AddressV = WRAP;
};

// Here we sample into the output of the compositing shader with some texture coordinate biz to simulate overscan and barrel distortion.
// We also apply the shadow mask (sometimes called "scanlines" here due to legacy naming) and saturation scaling.
float4 SampleCRT(float2 uv)
{
	float2 ScaledUV = uv;
	ScaledUV *= UVScalar;
	ScaledUV += UVOffset;
	
	float2 scanuv = ScaledUV * CRTMask_Scale;
	float3 scantex = tex2D(scanlinesSampler, scanuv).rgb;
	scantex += Tuning_Scanline_Brightness;	// Brighten up the shadow mask to mitigate darkening due to multiplication.
	scantex = lerp(float3(1,1,1), scantex, Tuning_Scanline_Opacity);

	// Apply overscan after scanline sampling is done.
	float2 overscanuv = (ScaledUV * Tuning_Overscan) - ((Tuning_Overscan - 1.0f) * 0.5f);
	
	// Curve UVs for composite texture inwards to garble things a bit.
	overscanuv = overscanuv - float2(0.5,0.5);
	float rsq = (overscanuv.x*overscanuv.x) + (overscanuv.y*overscanuv.y);
	overscanuv = overscanuv + (overscanuv * (Tuning_Barrel * rsq)) + float2(0.5,0.5);
		
	float3 comptex = tex2D(compFrameSampler, overscanuv).rgb;

	float4 emissive = float4(comptex * scantex, 1);
	float desat = dot(float4(0.299, 0.587, 0.114, 0.0), emissive);
	emissive = lerp(float4(desat,desat,desat,1), emissive, Tuning_Satur);
	
	return emissive;
}

// Here we sample the output of the compositing shader and apply Blinn-Phong lighting (diffuse + specular) plus a Fresnel rim lighting term.
float4 PS_SuperCRT(float4 pos : SV_Position, float2 uv : TEXCOORD0, float3 normFrac : TEXCOORD1, float3 camDirFrac : TEXCOORD2, float3 lightDirFrac : TEXCOORD3) : SV_Target
{	

	float4 color = tex2D(ReShade::BackBuffer, uv).rgba;
	
	float3 norm = normalize(normFrac);
	
	float3 camDir = normalize(camDirFrac);
	float3 lightDir = normalize(lightDirFrac);
	
	float3 refl = reflect(camDir, norm);
		
	float diffuse = saturate(dot(norm, lightDir));
	float4 colordiff = float4(0.175, 0.15, 0.2, 1) * diffuse * Tuning_Diff_Brightness;
	
	float3 floatVec = normalize(lightDir + camDir);
	float spec = saturate(dot(norm, floatVec));
	spec = pow(spec, Tuning_Spec_Power);
	float4 colorspec = float4(0.25, 0.25, 0.25, 1) * spec * Tuning_Spec_Brightness;
	
	float fres = 1.0f - dot(camDir, norm);
	fres = (fres*fres) * Tuning_Fres_Brightness;
	float4 colorfres = float4(0.45, 0.4, 0.5, 1) * fres;
	
	float4 emissive = SampleCRT(uv);
	
	float4 nearfinal = emissive;
	
	// color dims the edges of the CRT, but I don't really want that. CRTs don't do that!
	// This is really more about emulating ambient occlusion, but I'm applying it to the emissive, too.
	return (nearfinal * lerp(float4(1,1,1,1), color, Tuning_Dimming));
}

technique ScreenCRT
{
	pass Pass1
	{
		VertexShader=PostProcessVS;
		PixelShader=PS_SuperCRT;
	}
}