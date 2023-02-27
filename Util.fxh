
// I think this is how fmod does it in later versions?
#define mod(x, y) (x - y * floor(x / y))

// BT.601 Luma grayscale
float3 greyscale(float3 rgb) { return dot(rgb, float3(.299f, .587f, .114f)); }
float3 greyscale(float r, float g, float b) { return greyscale(float3(r,g,b)); }

// 13 weighted samples around the current pixel in two levels
// Jorge Jimenez (Activision, 2014), 13 bilinear fetching downsampling
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
float4 Downsample13(sampler s, float2 uv, float2 texelsize) {
    // @cleanup: Use easier to follow variable names/explanation for this

    // sample around the pixel in two layers
    // nw: northwest, tn: true north, ne: northeast
    // tw: true west, c: center, te: true east,
    // sw: southwest, ts: true south, se: southeast
    float4 c   = tex2D(s, uv);
    float4 tw  = tex2D(s, uv + float2(-1.f,  0.f) * texelsize);
    float4 nw1 = tex2D(s, uv + float2(-.5f, -.5f) * texelsize);
    float4 tn  = tex2D(s, uv + float2( 0.f, -1.f) * texelsize);
    float4 ne1 = tex2D(s, uv + float2( .5f, -.5f) * texelsize);
    float4 te  = tex2D(s, uv + float2( 1.f,  0.f) * texelsize);
    float4 se1 = tex2D(s, uv + float2( 1.f,  1.f) * texelsize);
    float4 ts  = tex2D(s, uv + float2( 0.f,  1.f) * texelsize);
    float4 sw1 = tex2D(s, uv + float2(-1.f,  1.f) * texelsize);
    float4 nw2 = tex2D(s, uv + float2(-1.f, -1.f) * texelsize);
    float4 ne2 = tex2D(s, uv + float2( 1.f, -1.f) * texelsize);
    float4 se2 = tex2D(s, uv + float2( .5f,  .5f) * texelsize);
    float4 sw2 = tex2D(s, uv + float2(-.5f,  .5f) * texelsize);

    float4 sampleout =
        (nw1 + ne1 + se1 + sw1) * .5f
        +   (nw2 + tn + c + tw) * .125f
        +   (tn + ne2 + te + c) * .125f
        +   (c + te + se2 + ts) * .125f
        +   (tw + c + ts + sw2) * .125f;
    
    return sampleout;
}

// Tent filter upsampling
// http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
float4 UpsampleTent(sampler smp, float2 uv, float2 texelsize, float2 samplescale) {
    float4 s;
    s =  tex2D(smp, uv + float2(-1., 1.) * texelsize * samplescale);
    s += tex2D(smp, uv + float2(0.,  1.)) * 2.0;
    s += tex2D(smp, uv + float2(1.,  1.));

    s += tex2D(smp, uv + float2(-1., 0.)) * 2.0;
    s += tex2D(smp, uv                  ) * 4.0;
    s += tex2D(smp, uv + float2(1.,  0.)) * 2.0;
    s += tex2D(smp, uv + float2(-1., -1.));
    s += tex2D(smp, uv + float2( 0., -1.)) * 2.0;
    s += tex2D(smp, uv + float2( 1., -1.));

    return s * (1.0 / 4.0);
}

// Snatched from https://learnopengl.com/Advanced-Lighting/HDR
float4 GLTonemapper(float4 col, float exposure) {
    const float gamma = 2.2;
    float3 hdrColor = col.rgb;
    float3 mapped = float3(1., 1., 1.) - exp(-hdrColor * exposure);
    mapped = pow(abs(mapped), float3(1., 1., 1.) / gamma);
    return float4(mapped, 1.);
}