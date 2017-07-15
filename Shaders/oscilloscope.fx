//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ReShade effect file
// visit facebook.com/MartyMcModding for news/updates
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Oscilloscope by Marty McFly
// For private use only!
// Copyright © 2008-2015 Marty McFly
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#include "ReShade.fxh"

uniform float3 OscilloscopeColor <
	ui_type = "color";
	ui_label = "Oscilloscope Color";
> = float3(0.012, 0.313, 0.588);

uniform float OscilloscopeLength <
	ui_type = "drag";
	ui_label = "Oscilloscope Length";
	ui_min = 0.000;
	ui_max = 0.016;
> = 0.008;

uniform float  Timer < source = "timer"; >;

struct VS_OUTPUT_POST
{
	float4 vpos : SV_Position;
	float2 txcoord : TEXCOORD0;
};

struct VS_INPUT_POST
{
	uint id : SV_VertexID;
};

VS_OUTPUT_POST VS_MasterEffect(VS_INPUT_POST IN)
{
	VS_OUTPUT_POST OUT;
	OUT.txcoord.x = (IN.id == 2) ? 2.0 : 0.0;
	OUT.txcoord.y = (IN.id == 1) ? 2.0 : 0.0;
	OUT.vpos = float4(OUT.txcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
	return OUT;
}

float GetLinearDepth(float2 coords)
{
 	//return 1.0/(1000.0-999.0*tex2Dlod(SamplerDepth, float4(coords.xy,0,0)).x);
	return ReShade::GetLinearizedDepth(coords);
}

float3 GetPosition(float2 coords)
{
	float EyeDepth = GetLinearDepth(coords.xy)*RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
	return float3((coords.xy * 2.0 - 1.0)*EyeDepth,EyeDepth);
}

float3 GetNormalFromDepth(float2 coords)
{
	float3 centerPos = GetPosition(coords.xy);
	float2 offs = ReShade::PixelSize;
	float3 ddx1 = GetPosition(coords.xy + float2(offs.x, 0)) - centerPos;
	float3 ddx2 = centerPos - GetPosition(coords.xy + float2(-offs.x, 0));

	float3 ddy1 = GetPosition(coords.xy + float2(0, offs.y)) - centerPos;
	float3 ddy2 = centerPos - GetPosition(coords.xy + float2(0, -offs.y));

	ddx1 = lerp(ddx1, ddx2, abs(ddx1.z) > abs(ddx2.z));
	ddy1 = lerp(ddy1, ddy2, abs(ddy1.z) > abs(ddy2.z));

	float3 normal = cross(ddy1, ddx1);
	
	return normalize(normal);
}

float hash(float n) { return frac(sin(n)*753.5453123);}
float Get3DNoise(in float3 pos)
{
	float3 p = floor(pos);
	float3 f = frac(pos);

	float n = p.x + p.y*157.0 + 113.0*p.z;
    	return lerp(lerp(lerp( hash(n+  0.0), hash(n+  1.0),f.x),
               lerp( hash(n+157.0), hash(n+158.0),f.x),f.y),
               lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
               lerp( hash(n+270.0), hash(n+271.0),f.x),f.y),f.z);
}

float4 PS_ME_SAO(VS_OUTPUT_POST IN) : COLOR
{
	float3 normal = GetNormalFromDepth(IN.txcoord.xy);
	return normal.xyzz*0.5+0.5;
}

float4 PS_ME_SAO2(VS_OUTPUT_POST IN) : COLOR
{
	float4 res = 1.0;


	float3 base = tex2D(ReShade::BackBuffer, IN.txcoord.xy).xyz * 2.0 - 1.0;
	float3 pos = GetPosition(IN.txcoord.xy);

	float minlength = 100000.0;

	for(float x = -4; x<=4; x++)
	for(float y = -4; y<=4; y++)
	{
		float2 tempoffset = float2(x,y) * ReShade::PixelSize.xy * 1.5 + IN.txcoord.xy;
		float3 tempsample = tex2D(ReShade::BackBuffer, tempoffset.xy).xyz * 2.0 - 1.0;

		float diff = length(tempsample-base);
		if(diff > 0.05) minlength = min(minlength,length(float2(x,y)));
	}

	float3 normal = GetNormalFromDepth(IN.txcoord.xy);

	float NdotL = saturate(dot(normal.xyz,float3(0.0,0.0,-1.0)));
	NdotL = pow(NdotL,10.0)*3;


	float factor = smoothstep(0.0,5.6,minlength);
	factor = 1-sqrt(factor);

	factor *= Get3DNoise(pos + float3(Timer.x * 0.003,Timer.x*0.004,-Timer.x*0.01));
	factor = factor*factor*3;

	float3 color = OscilloscopeColor;

	color.xyz *= factor + NdotL;

	float fogfactor = 1.0-1.0/exp(length(pos)*OscilloscopeLength);

	color.xyz = lerp(color.xyz,0.0, fogfactor);

	res.xyz = color.xyz;
	return res;

}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



technique Oscilloscope
{
	pass P1
	{
		VertexShader = PostProcessVS;
		PixelShader  = PS_ME_SAO;
	}
	pass P2
	{
		VertexShader = PostProcessVS;
		PixelShader  = PS_ME_SAO2;
	}
}