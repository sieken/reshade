#pragma once

// Triangle covering the entire screen, from the ReShade reference
void PostProcessVS(uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD0) {
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2, -2) + float2(-1, 1), 0, 1);
}

namespace ReShade {
    texture BackBufferTex : COLOR;
    texture DepthBufferTex : DEPTH;

    sampler BackBuffer { Texture = BackBufferTex; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
    sampler DepthBuffer { Texture = DepthBufferTex; AddressU = BORDER; AddressV = BORDER; AddressW = BORDER; };
}