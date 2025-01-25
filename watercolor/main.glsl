/****************************************************
 * Noise Texture
 ****************************************************/
 
// implementation of MurmurHash (https://sites.google.com/site/murmurhash/) for a  
// single unsigned integer.

uint perlin_hash(uint x, uint seed) {
    const uint m = 0x5bd1e995U;
    uint hash = seed;
    // process input
    uint k = x;
    k *= m;
    k ^= k >> 24;
    k *= m;
    hash *= m;
    hash ^= k;
    // some final mixing
    hash ^= hash >> 13;
    hash *= m;
    hash ^= hash >> 15;
    return hash;
}

// implementation of MurmurHash (https://sites.google.com/site/murmurhash/) for a  
// 2-dimensional unsigned integer input vector.

uint perlin_hash(uvec2 x, uint seed){
    const uint m = 0x5bd1e995U;
    uint hash = seed;
    // process first vector element
    uint k = x.x; 
    k *= m;
    k ^= k >> 24;
    k *= m;
    hash *= m;
    hash ^= k;
    // process second vector element
    k = x.y; 
    k *= m;
    k ^= k >> 24;
    k *= m;
    hash *= m;
    hash ^= k;
	// some final mixing
    hash ^= hash >> 13;
    hash *= m;
    hash ^= hash >> 15;
    return hash;
}


vec2 gradient_direction(uint hash) {
    switch (int(hash) & 3) { // look at the last two bits to pick a gradient direction
    case 0:
        return vec2(1.0, 1.0);
    case 1:
        return vec2(-1.0, 1.0);
    case 2:
        return vec2(1.0, -1.0);
    case 3:
        return vec2(-1.0, -1.0);
    }
}

float interpolate(float value1, float value2, float value3, float value4, vec2 t) {
    return mix(mix(value1, value2, t.x), mix(value3, value4, t.x), t.y);
}

vec2 fade(vec2 t) {
    // 6t^5 - 15t^4 + 10t^3
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float perlin_noise(vec2 position, uint seed) {
    vec2 floorPosition = floor(position);
    vec2 fractPosition = position - floorPosition;
    uvec2 cellCoordinates = uvec2(floorPosition);
    float value1 = dot(gradient_direction(perlin_hash(cellCoordinates, seed)), fractPosition);
    float value2 = dot(gradient_direction(perlin_hash((cellCoordinates + uvec2(1, 0)), seed)), fractPosition - vec2(1.0, 0.0));
    float value3 = dot(gradient_direction(perlin_hash((cellCoordinates + uvec2(0, 1)), seed)), fractPosition - vec2(0.0, 1.0));
    float value4 = dot(gradient_direction(perlin_hash((cellCoordinates + uvec2(1, 1)), seed)), fractPosition - vec2(1.0, 1.0));
    return interpolate(value1, value2, value3, value4, fade(fractPosition));
}

float perlin_noise(vec2 position, float frequency, float detail, float roughness, float lacunarity, uint seed) {
    float value = 1.0;
    float amplitude = 1.0;
    float currentFrequency = frequency;
    uint currentSeed = seed;
    for (int i = 0; i < int(detail); i++) {
        currentSeed = perlin_hash(currentSeed, 0x0U); // create a new seed for each octave
        value *= (amplitude * perlin_noise(position * currentFrequency, currentSeed) + 1.0);
        amplitude *= roughness;
        currentFrequency *= lacunarity;
    }
    
    float rmd = detail - floor(detail);
    if (rmd != 0.0f) {
        value *= (rmd * amplitude * perlin_noise(position * currentFrequency, currentSeed) + 1.0);
    }
    
    return value;
}

/****************************************************
 * Random
 ****************************************************/

float random_hash_01( float n ) { return fract(sin(n)*43758.5453); }

/****************************************************
 * Voronoi Texture
 ****************************************************/

vec2  voronoi_hash( vec2  p ) { p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) ); return fract(sin(p)*43758.5453); }

// The parameter w controls the smoothness
vec4 voronoi( in vec2 x, float w )
{
    vec2 n = floor( x );
    vec2 f = fract( x );

	vec4 m = vec4( 8.0, 0.0, 0.0, 0.0 );
    for( int j=-2; j<=2; j++ )
    for( int i=-2; i<=2; i++ )
    {
        vec2 g = vec2( float(i),float(j) );
        vec2 o = voronoi_hash( n + g );
		
		// animate
        //o = 0.5 + 0.5*sin( iTime*6.2831*o );

        // distance to cell
		float d = length(g - f + o);
		
        // cell color
        uint seed = uint(1e+6 * random_hash_01(iTime / float(1e+6)));
        float random = random_hash_01(float(seed) * (sin(n.x+g.x) + cos(n.y+g.y)));
        vec3 col = 0.5 + 0.5*vec3(random);
        // in linear space
        col = col*col;
        
        // do the smooth min for colors and distances		
		float h = smoothstep( -1.0, 1.0, (m.x-d)/w );
	    m.x   = mix( m.x,     d, h ) - h*(1.0-h)*w/(1.0+3.0*w); // distance
		m.yzw = mix( m.yzw, col, h ) - h*(1.0-h)*w/(1.0+3.0*w); // color
    }
	
	return m;
}

#define DISTORT_STRENGTH 7.0
#define VORONOI_SCALE 15.0
#define VORONOI_SMOOTH 1.0
#define NOISE_SCALE 0.05
#define NOISE_FREQUENCY 5.0
#define NOISE_DETAIL 5.0
#define NOISE_ROUGHNESS 0.561
#define NOISE_LACUNARITY 1.5

vec2 distort(vec2 pos, float strength) {
    uint seed = uint(1e+6 * random_hash_01(iTime / float(1e+6)));
    strength *= 5e-2;
    float frequency = 5.0 * NOISE_FREQUENCY;
    float distort = perlin_noise(pos * NOISE_SCALE, frequency, NOISE_DETAIL, NOISE_ROUGHNESS, NOISE_LACUNARITY, seed);
    float invdistort = 1. - distort;
    return vec2(pos.x + distort * strength, pos.y + invdistort * strength);
}

/****************************************************
 * Blur
 ****************************************************/

#ifdef HW_PERFORMANCE
#define SAMPLES 50.0
#else
#define SAMPLES 200.0
#endif

#define BLUR_RADIUS 50.0

vec4 blur_box(sampler2D tex, vec2 texel, vec2 uv, vec2 rect)
{
    vec4 total = vec4(0);
    
    float dist = inversesqrt(SAMPLES);
    for(float i = -0.5; i<=0.5; i+=dist)
    for(float j = -0.5; j<=0.5; j+=dist)
    {
        vec2 coord = uv+vec2(i,j)*rect*texel;
        total += texture(tex,coord);
    }
    
    return total * dist * dist;
}

/****************************************************
 * Toon
 ****************************************************/

vec3 toon_effect(vec3 c, int f, int m)
{
    c = floor(c * float(m) / float(f)) / float(m) * float(f);
    return c;
}

/****************************************************
 * MainImage
 ****************************************************/

#iChannel0 "file://image.jpg"

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float weight;

    // tex sampling
    vec2 texel = 1. / iResolution.xy;
    vec2 coord = fragCoord*texel;
    vec2 uv = fract(coord);
    
    // noise sampling
    vec2 pos = fragCoord / iResolution.y; 
    vec4 v = voronoi(distort(pos * VORONOI_SCALE, DISTORT_STRENGTH), VORONOI_SMOOTH);
    
    vec3 col = texture(iChannel0,uv).xyz;
   
    // mix blur
    float radius = BLUR_RADIUS * v.y;
    vec3 blur = blur_box(iChannel0, texel, uv, vec2(radius, radius)).xyz;
    weight = (1.0 - v.y) * 0.25;
    vec3 layer0 = weight * col + (1.0 - weight) * blur;
    
    // mix toon
    vec3 layer1 = toon_effect(layer0, 125, 256);
    weight = (1.0 - v.y) * 0.15;
    col = weight * layer1 + (1.0 - weight) * layer0;
    col *= (1.0 - v.y * 0.1);
    
	fragColor = vec4(col.xyz, 1.0);

    // debug
    //col = blur.xyz;
    //col = sqrt(v.yzw);
    //col = vec3(v.w);
	
    fragColor = vec4( col, 1.0 );
}